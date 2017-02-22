/// <reference types="es6-collections" />
/// <reference types="node" />

import {DebugSession, InitializedEvent, TerminatedEvent, StoppedEvent, BreakpointEvent, OutputEvent, Event,	Thread, StackFrame, Scope, Source, Handles, Breakpoint} from 'vscode-debugadapter';
import {DebugProtocol} from 'vscode-debugprotocol';
import {ChildProcess, spawn} from "child_process";
import {basename} from 'path';

export interface LaunchRequestArguments extends DebugProtocol.LaunchRequestArguments {

	scriptPath: string;
	commandLineArguments: string;
	bashDbPath: string;
	bashPath: string;
	showDebugOutput?: boolean;
}

class BashDebugSession extends DebugSession {

	private static THREAD_ID = 42;
	private static END_MARKER = "############################################################";

	private debuggerProcess: ChildProcess;

	private currentBreakpointIds = new Map<string, Array<number>>();

	private fullDebugOutput = [""];
	private fullDebugOutputIndex = 0;

	private debuggerExecutableBusy = false;
	private debuggerExecutableClosing = false;

	private responsivityFactor = 5;

	private debuggerProcessParentId = -1;

	// https://github.com/Microsoft/BashOnWindows/issues/1489
	 private debugPipeIndex = (process.platform == "win32") ? 2 : 3;

	public constructor() {
		super();
		this.setDebuggerLinesStartAt1(true);
		this.setDebuggerColumnsStartAt1(true);
	}

	protected initializeRequest(response: DebugProtocol.InitializeResponse, args: DebugProtocol.InitializeRequestArguments): void {

		response.body.supportsConditionalBreakpoints = false;
		response.body.supportsConfigurationDoneRequest = false;
		response.body.supportsEvaluateForHovers = true;
		response.body.supportsStepBack = false;
		response.body.supportsSetVariable = false;
		this.sendResponse(response);
	}

	protected disconnectRequest(response: DebugProtocol.DisconnectResponse, args: DebugProtocol.DisconnectArguments): void {
		this.debuggerExecutableBusy = false;

		this.debuggerProcess.on("exit", ()=> {
			this.debuggerExecutableClosing = true;
			this.sendResponse(response)
		});

		spawn("bash", ["-c", `pkill -KILL -P ${this.debuggerProcessParentId}`]);
	}

	protected launchRequest(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		if (!args.bashDbPath) {
			args.bashDbPath = "bashdb";
		}

		if (!args.bashPath) {
			args.bashPath = "bash";
		}

		var fifo_path = "/tmp/vscode-bash-debug-fifo-" + (Math.floor(Math.random() * 10000) + 10000);

		// use fifo, because --tty '&1' does not work properly for subshell (when bashdb spawns - $() )
		// when this is fixed in bashdb, use &1
		this.debuggerProcess = spawn(args.bashPath, ["-c", `

			# http://tldp.org/LDP/abs/html/io-redirection.html

			function cleanup()
			{
				exit_code=$?
				exec 4>&-
				rm "${fifo_path}";
				exit $exit_code;
			}
			trap 'cleanup' ERR SIGINT SIGTERM

			mkfifo "${fifo_path}"
			cat "${fifo_path}" >&${this.debugPipeIndex} &
			exec 4>"${fifo_path}" 		# Keep open for writing, bashdb seems close after every write.
			cat | ${args.bashDbPath} --quiet --tty "${fifo_path}" -- "${args.scriptPath}" ${args.commandLineArguments}

			cleanup`
		], {stdio: ["pipe", "pipe", "pipe", "pipe"]});

		this.debuggerProcess.on("error", (error) => {
			this.sendEvent(new OutputEvent(`${error}`, 'stderr'));
		});

		this.processDebugTerminalOutput();

		this.debuggerProcess.stdin.write(`print "$PPID"\nhandle INT stop\nprint "${BashDebugSession.END_MARKER}"\n`);

		this.debuggerProcess.stdio[1].on("data", (data) => {
			this.sendEvent(new OutputEvent(`${data}`, 'stdout'));
		});

		this.debuggerProcess.stdio[2].on("data", (data) => {
			this.sendEvent(new OutputEvent(`${data}`, 'stderr'));
		});

		this.debuggerProcess.stdio[3].on("data", (data) => {
			if (args.showDebugOutput) {
				this.sendEvent(new OutputEvent(`${data}`, 'console'));
			}
		});

		this.scheduleExecution(() => this.launchRequestFinalize(response, args));
	}

	private launchRequestFinalize(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		for (var i = 0; i < this.fullDebugOutput.length; i++) {
			if (this.fullDebugOutput[i] == BashDebugSession.END_MARKER) {

				this.debuggerProcessParentId = parseInt(this.fullDebugOutput[i-1]);
				this.sendResponse(response);
				this.sendEvent(new OutputEvent(`Sending InitializedEvent`, 'telemetry'));
				this.sendEvent(new InitializedEvent());

				var interval = setInterval((data) => {
					for (; this.fullDebugOutputIndex < this.fullDebugOutput.length - 1; this.fullDebugOutputIndex++)
					{
						var line = this.fullDebugOutput[this.fullDebugOutputIndex];

						if (line.indexOf("(/") == 0 && line.indexOf("):") == line.length-2)
						{
							this.sendEvent(new OutputEvent(`Sending StoppedEvent`, 'telemetry'));
							this.sendEvent(new StoppedEvent("break", BashDebugSession.THREAD_ID));
						}
						else if (line.indexOf("terminated") > 0)
						{
							clearInterval(interval);
							this.sendEvent(new OutputEvent(`Sending TerminatedEvent`, 'telemetry'));
							this.sendEvent(new TerminatedEvent());
						}
					}
				},
				this.responsivityFactor);
				return;
			}
		}

		this.scheduleExecution(()=>this.launchRequestFinalize(response, args));
	}


	protected setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): void {

		if (this.debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.setBreakPointsRequest(response, args));
			return;
		}

		if (!this.currentBreakpointIds[args.source.path]){
			this.currentBreakpointIds[args.source.path] = [];
		}

		var sourcePath = (process.platform == "win32") ? this.getLinuxPathFromWindows(args.source.path) : args.source.path;

		var setBreakpointsCommand = `print 'delete <${this.currentBreakpointIds[args.source.path].join(" ")}>'\ndelete ${this.currentBreakpointIds[args.source.path].join(" ")}\nload ${sourcePath}\n`;
		args.breakpoints.forEach((b)=>{ setBreakpointsCommand += `print ' <${sourcePath}:${b.line}> '\nbreak ${sourcePath}:${b.line}\n` });

		this.debuggerExecutableBusy = true;
		var currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`${setBreakpointsCommand}print '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(()=>	this.setBreakPointsRequestFinalize(response, args, currentLine));
	}

	private setBreakPointsRequestFinalize(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			this.currentBreakpointIds[args.source.path] = [];
			var breakpoints = new Array<Breakpoint>();

			for (var i = currentOutputLength; i < this.fullDebugOutput.length - 2; i++ ){

				if (this.fullDebugOutput[i-1].indexOf(" <") == 0 && this.fullDebugOutput[i-1].indexOf("> ") > 0) {

					var lineNodes = this.fullDebugOutput[i].split(" ");
					const bp = <DebugProtocol.Breakpoint> new Breakpoint(true, this.convertDebuggerLineToClient(parseInt(lineNodes[lineNodes.length-1].replace(".",""))));
					bp.id = parseInt(lineNodes[1]);
					breakpoints.push(bp);
					this.currentBreakpointIds[args.source.path].push(bp.id);
				}
			}

			response.body = { breakpoints: breakpoints };
			this.debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		this.scheduleExecution(()=> this.setBreakPointsRequestFinalize(response, args, currentOutputLength));
	}

	protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {

		response.body = { threads: [ new Thread(BashDebugSession.THREAD_ID, "Bash thread") ]};
		this.sendResponse(response);
	}

	protected stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {

		if (this.debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.stackTraceRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		var currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print backtrace\nbacktrace\nprint '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(() => this.stackTraceRequestFinalize(response, args, currentLine));
	}

	private stackTraceRequestFinalize(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			var lastStackLineIndex = this.fullDebugOutput.length - 3;

			var frames = new Array<StackFrame>();
			for (var i= currentOutputLength; i <= lastStackLineIndex ; i++) {
				var lineContent = this.fullDebugOutput[i];
				var frameIndex = parseInt(lineContent.substr(2, 2));
				var frameText = lineContent;
				var frameSourcePath = lineContent.substr(lineContent.lastIndexOf("`") + 1, lineContent.lastIndexOf("'") - lineContent.lastIndexOf("`") - 1);
				var frameLine = parseInt(lineContent.substr(lineContent.lastIndexOf(" ")));

				if ((process.platform == "win32"))
				{
					frameSourcePath = this.getWindowsPathFromLinux(frameSourcePath);
				}

				frames.push(new StackFrame(
					frameIndex,
					frameText,
					new Source(basename(frameSourcePath), this.convertDebuggerPathToClient(frameSourcePath)),
					this.convertDebuggerLineToClient(frameLine)
					));
			}

			var totalFrames = this.fullDebugOutput.length - currentOutputLength -1;

			const startFrame = typeof args.startFrame === 'number' ? args.startFrame : 0;
			const maxLevels = typeof args.levels === 'number' ? args.levels : 100;
			frames = frames.slice(startFrame, Math.min(startFrame + maxLevels, frames.length));

			response.body = { stackFrames: frames, totalFrames: totalFrames };
			this.debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		this.scheduleExecution(() => this.stackTraceRequestFinalize(response, args, currentOutputLength));
	}

	protected scopesRequest(response: DebugProtocol.ScopesResponse, args: DebugProtocol.ScopesArguments): void {

		var scopes = [ new Scope("Local", this.fullDebugOutputIndex, false) ];
		response.body = { scopes: scopes };
		this.sendResponse(response);
	}

	protected variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): void {

		if (this.debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.variablesRequest(response, args));
			return;
		}

		var getVariablesCommand = `info program\n`;

		const count = typeof args.count === 'number' ? args.count : 100;
		const start = typeof args.start === 'number' ? args.start : 0;
		var variableDefinitions = ["PWD", "EUID","#","0","-"];
		variableDefinitions = variableDefinitions.slice(start, Math.min(start + count, variableDefinitions.length));

		variableDefinitions.forEach((v)=>{ getVariablesCommand += `print ' <$${v}> '\nexamine $${v}\n` });

		this.debuggerExecutableBusy = true;
		var currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`${getVariablesCommand}print '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(()=> this.variablesRequestFinalize(response, args, currentLine));
	}

	private variablesRequestFinalize(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			var variables = [];

			for (var i = currentOutputLength; i < this.fullDebugOutput.length - 2; i++ ){

				if (this.fullDebugOutput[i-1].indexOf(" <") == 0 && this.fullDebugOutput[i-1].indexOf("> ") > 0) {

					var lineNodes = this.fullDebugOutput[i].split(" ");
					variables.push({
						name: `${this.fullDebugOutput[i-1].replace(" <", "").replace("> ", "")}`,
						type: "string",
						value: this.fullDebugOutput[i],
						variablesReference: 0
					});
				}
			}

			response.body = { variables: variables };
			this.debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		this.scheduleExecution(()=> this.variablesRequestFinalize(response, args, currentOutputLength));
	}

	protected continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {

		if (this.debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.continueRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		var currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print continue\ncontinue\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(()=>this.continueRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private continueRequestFinalize(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			this.debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(()=>this.continueRequestFinalize(response, args, currentOutputLength));
	}

	protected nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {

		if (this.debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.nextRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		var currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print next\nnext\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(()=>this.nextRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private nextRequestFinalize(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			this.debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(()=>this.nextRequestFinalize(response, args, currentOutputLength));
	}

	protected stepInRequest(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments): void {

		if (this.debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.stepInRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		var currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print step\nstep\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(()=>this.stepInRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private stepInRequestFinalize(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments, currentOutputLength:number): void {
		if (this.promptReached(currentOutputLength))
		{
			this.debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(()=>this.stepInRequestFinalize(response, args, currentOutputLength));
	}

	protected stepOutRequest(response: DebugProtocol.StepOutResponse, args: DebugProtocol.StepOutArguments): void {

		if (this.debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.stepOutRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		var currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print finish\nfinish\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(()=>this.stepOutRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private stepOutRequestFinalize(response: DebugProtocol.StepOutResponse, args: DebugProtocol.StepOutArguments, currentOutputLength:number): void {
		if (this.promptReached(currentOutputLength))
		{
			this.debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(()=>this.stepOutRequestFinalize(response, args, currentOutputLength));
	}

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {

		if (this.debuggerProcess == null){
			response.body = { result: `${args.expression} = ''`, variablesReference: 0	};
			this.debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		if (this.debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.evaluateRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		var currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print 'examine <${args.expression}>'\nexamine ${args.expression.replace("\"", "")}\nprint '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(()=>this.evaluateRequestFinalize(response, args, currentLine));
	}

	private evaluateRequestFinalize(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			response.body = { result: `${args.expression} = '${this.fullDebugOutput[currentOutputLength]}'`, variablesReference: 0	};

			this.debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		this.scheduleExecution(()=>this.evaluateRequestFinalize(response, args, currentOutputLength));
	}

	protected pauseRequest(response: DebugProtocol.PauseResponse, args: DebugProtocol.PauseArguments): void {
		if (args.threadId == BashDebugSession.THREAD_ID) {
			spawn("bash", ["-c", `pkill -INT -P ${this.debuggerProcessParentId} -f bashdb`]).on("exit", () => this.sendResponse(response));
			return;
		}

		response.success = false;
		this.sendResponse(response);
	}

	private removePrompt(line : string): string{
		if (line.indexOf("bashdb<") == 0) {
			return line.substr(line.indexOf("> ") + 2);
		}

		return line;
	}

	private promptReached(currentOutputLength:number) : boolean{
		return this.fullDebugOutput.length > currentOutputLength && this.fullDebugOutput[this.fullDebugOutput.length -2] == BashDebugSession.END_MARKER;
	}

	private processDebugTerminalOutput(): void {

		this.debuggerProcess.stdio[this.debugPipeIndex].on('data', (data) => {

			if (this.fullDebugOutput.length == 1 && data.indexOf("Reading ") == 0) {
				// Before debug run, there is no newline
				return;
			}

			var list = data.toString().split("\n", -1);
			var fullLine = `${this.fullDebugOutput.pop()}${list.shift()}`;
			this.fullDebugOutput.push(this.removePrompt(fullLine));
			list.forEach(l => this.fullDebugOutput.push(this.removePrompt(l)));
		})
	}

	private scheduleExecution(callback: (...args: any[]) => void) : void {
		if (!this.debuggerExecutableClosing) {
			setTimeout(() => callback(), this.responsivityFactor);
		}
	}

	private getWindowsPathFromLinux(linuxPath:string) : string {
		return linuxPath.substr("/mnt/".length, 1).toUpperCase() + ":" + linuxPath.substr("/mnt/".length + 1).split("/").join("\\");
	}

	private getLinuxPathFromWindows(windowsPath:string) : string {
		return "/mnt/" + windowsPath.substr(0, 1).toLowerCase() + windowsPath.substr("X:".length).split("\\").join("/");
	}
}

DebugSession.run(BashDebugSession);
