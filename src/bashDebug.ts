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
	showDebugOutput?: boolean;
}

class BashDebugSession extends DebugSession {

	private static THREAD_ID = 42;
	private static END_MARKER = "############################################################";

	private _debuggerProcess: ChildProcess;

	private _currentBreakpointIds = new Map<string, Array<number>>();

	private _fullDebugOutput = [""];
	private _fullDebugOutputIndex = 0;

	private _debuggerExecutableBusy = false;
	private _debuggerExecutableClosing = false;

	private _responsivityFactor = 5;

	private _debuggerProcessParentId = -1;

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
		this._debuggerExecutableBusy = false;

		this._debuggerProcess.on("exit", ()=> {
			this._debuggerExecutableClosing = true;
			this.sendResponse(response)
		});

		spawn("bash", ["-c", `pkill -9 -P ${this._debuggerProcessParentId}`]);
	}

	protected launchRequest(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		if (!args.bashDbPath) {
			args.bashDbPath = "bashdb";
		}

		// use fifo, because --tty '&1' does not work properly for subshell (when bashdb spawns - $() )
		// when this is fixed in bashdb, use &1
		this._debuggerProcess = spawn("bash", ["-c", `

			# http://tldp.org/LDP/abs/html/io-redirection.html

			fifo_path=$(mktemp --dry-run /tmp/vscode-bash-debug-fifo.XXXXXX)

			function cleanup()
			{
				exit_code=$?
				exec 4>&-
				rm "$fifo_path";
				exit $exit_code;
			}
			trap 'cleanup' ERR SIGINT SIGTERM
			mkfifo "$fifo_path"
			cat "$fifo_path" >&3 & 		# Open for reading in background.
			exec 4>"$fifo_path" 		# Keep open for writing, bashdb seems close after every write.
			${args.bashDbPath} --quiet --tty "$fifo_path" -- "${args.scriptPath}" ${args.commandLineArguments}
			cleanup`
		], {stdio: ["pipe", "pipe", "pipe", "pipe"]});

		this.processDebugTerminalOutput(args.showDebugOutput == true);

		this._debuggerProcess.stdin.write(`print "$PPID"\nprint "${BashDebugSession.END_MARKER}"\n`);

		this._debuggerProcess.stdout.on("data", (data) => {
			this.sendEvent(new OutputEvent(`${data}`, 'stdout'));
		});

		this._debuggerProcess.stderr.on("data", (data) => {
			this.sendEvent(new OutputEvent(`${data}`, 'stderr'));
		});

		this._debuggerProcess.stdio[3].on("data", (data) => {
			if (args.showDebugOutput) {
				this.sendEvent(new OutputEvent(`${data}`, 'console'));
			}
		});

		this.scheduleExecution(() => this.launchRequestFinalize(response, args));
	}

	private launchRequestFinalize(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		for (var i = 0; i < this._fullDebugOutput.length; i++) {
			if (this._fullDebugOutput[i] == BashDebugSession.END_MARKER) {

				this._debuggerProcessParentId = parseInt(this._fullDebugOutput[i-1]);
				this.sendResponse(response);
				this.sendEvent(new OutputEvent(`Sending InitializedEvent`, 'telemetry'));
				this.sendEvent(new InitializedEvent());

				var interval = setInterval((data) => {
					for (; this._fullDebugOutputIndex < this._fullDebugOutput.length - 1; this._fullDebugOutputIndex++)
					{
						var line = this._fullDebugOutput[this._fullDebugOutputIndex];

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
				this._responsivityFactor);
				return;
			}
		}

		this.scheduleExecution(()=>this.launchRequestFinalize(response, args));
	}


	protected setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): void {

		if (this._debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.setBreakPointsRequest(response, args));
			return;
		}

		if (!this._currentBreakpointIds[args.source.path]){
			this._currentBreakpointIds[args.source.path] = [];
		}

		var setBreakpointsCommand = `print 'delete <${this._currentBreakpointIds[args.source.path].join(" ")}>'\ndelete ${this._currentBreakpointIds[args.source.path].join(" ")}\nload ${args.source.path}\n`;
		args.breakpoints.forEach((b)=>{ setBreakpointsCommand += `print ' <${args.source.path}:${b.line}> '\nbreak ${args.source.path}:${b.line}\n` });

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this._debuggerProcess.stdin.write(`${setBreakpointsCommand}print '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(()=>	this.setBreakPointsRequestFinalize(response, args, currentLine));
	}

	private setBreakPointsRequestFinalize(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			this._currentBreakpointIds[args.source.path] = [];
			var breakpoints = new Array<Breakpoint>();

			for (var i = currentOutputLength; i < this._fullDebugOutput.length - 2; i++ ){

				if (this._fullDebugOutput[i-1].indexOf(" <") == 0 && this._fullDebugOutput[i-1].indexOf("> ") > 0) {

					var lineNodes = this._fullDebugOutput[i].split(" ");
					const bp = <DebugProtocol.Breakpoint> new Breakpoint(true, this.convertDebuggerLineToClient(parseInt(lineNodes[lineNodes.length-1].replace(".",""))));
					bp.id = parseInt(lineNodes[1]);
					breakpoints.push(bp);
					this._currentBreakpointIds[args.source.path].push(bp.id);
				}
			}

			response.body = { breakpoints: breakpoints };
			this._debuggerExecutableBusy = false;
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

		if (this._debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.stackTraceRequest(response, args));
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this._debuggerProcess.stdin.write(`print backtrace\nbacktrace\nprint '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(() => this.stackTraceRequestFinalize(response, args, currentLine));
	}

	private stackTraceRequestFinalize(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			var lastStackLineIndex = this._fullDebugOutput.length - 3;

			var frames = new Array<StackFrame>();
			for (var i= currentOutputLength; i <= lastStackLineIndex ; i++) {
				var lineContent = this._fullDebugOutput[i];
				var frameIndex = parseInt(lineContent.substr(2, 2));
				var frameText = lineContent;
				var frameSourcePath = lineContent.substr(lineContent.lastIndexOf("`") + 1, lineContent.lastIndexOf("'") - lineContent.lastIndexOf("`") - 1);
				var frameLine = parseInt(lineContent.substr(lineContent.lastIndexOf(" ")));

				frames.push(new StackFrame(
					frameIndex,
					frameText,
					new Source(basename(frameSourcePath), this.convertDebuggerPathToClient(frameSourcePath)),
					this.convertDebuggerLineToClient(frameLine)
					));
			}

			var totalFrames = this._fullDebugOutput.length - currentOutputLength -1;

			const startFrame = typeof args.startFrame === 'number' ? args.startFrame : 0;
			const maxLevels = typeof args.levels === 'number' ? args.levels : 100;
			frames = frames.slice(startFrame, Math.min(startFrame + maxLevels, frames.length));

			response.body = { stackFrames: frames, totalFrames: totalFrames };
			this._debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		this.scheduleExecution(() => this.stackTraceRequestFinalize(response, args, currentOutputLength));
	}

	protected scopesRequest(response: DebugProtocol.ScopesResponse, args: DebugProtocol.ScopesArguments): void {

		var scopes = [ new Scope("Local", this._fullDebugOutputIndex, false) ];
		response.body = { scopes: scopes };
		this.sendResponse(response);
	}

	protected variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): void {

		if (this._debuggerExecutableBusy)
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

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this._debuggerProcess.stdin.write(`${getVariablesCommand}print '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(()=> this.variablesRequestFinalize(response, args, currentLine));
	}

	private variablesRequestFinalize(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			var variables = [];

			for (var i = currentOutputLength; i < this._fullDebugOutput.length - 2; i++ ){

				if (this._fullDebugOutput[i-1].indexOf(" <") == 0 && this._fullDebugOutput[i-1].indexOf("> ") > 0) {

					var lineNodes = this._fullDebugOutput[i].split(" ");
					variables.push({
						name: `${this._fullDebugOutput[i-1].replace(" <", "").replace("> ", "")}`,
						type: "string",
						value: this._fullDebugOutput[i],
						variablesReference: 0
					});
				}
			}

			response.body = { variables: variables };
			this._debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		this.scheduleExecution(()=> this.variablesRequestFinalize(response, args, currentOutputLength));
	}

	protected continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {

		if (this._debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.continueRequest(response, args));
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this._debuggerProcess.stdin.write(`print continue\ncontinue\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(()=>this.continueRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private continueRequestFinalize(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			this._debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(()=>this.continueRequestFinalize(response, args, currentOutputLength));
	}

	protected nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {

		if (this._debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.nextRequest(response, args));
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this._debuggerProcess.stdin.write(`print next\nnext\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(()=>this.nextRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private nextRequestFinalize(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			this._debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(()=>this.nextRequestFinalize(response, args, currentOutputLength));
	}

	protected stepInRequest(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments): void {

		if (this._debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.stepInRequest(response, args));
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this._debuggerProcess.stdin.write(`print step\nstep\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(()=>this.stepInRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private stepInRequestFinalize(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments, currentOutputLength:number): void {
		if (this.promptReached(currentOutputLength))
		{
			this._debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(()=>this.stepInRequestFinalize(response, args, currentOutputLength));
	}

	protected stepOutRequest(response: DebugProtocol.StepOutResponse, args: DebugProtocol.StepOutArguments): void {

		if (this._debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.stepOutRequest(response, args));
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this._debuggerProcess.stdin.write(`print finish\nfinish\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(()=>this.stepOutRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private stepOutRequestFinalize(response: DebugProtocol.StepOutResponse, args: DebugProtocol.StepOutArguments, currentOutputLength:number): void {
		if (this.promptReached(currentOutputLength))
		{
			this._debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(()=>this.stepOutRequestFinalize(response, args, currentOutputLength));
	}

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {

		if (this._debuggerExecutableBusy)
		{
			this.scheduleExecution(()=>	this.evaluateRequest(response, args));
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this._debuggerProcess.stdin.write(`print 'examine <${args.expression}>'\nexamine ${args.expression.replace("\"", "")}\nprint '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(()=>this.evaluateRequestFinalize(response, args, currentLine));
	}

	private evaluateRequestFinalize(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments, currentOutputLength:number): void {

		if (this.promptReached(currentOutputLength))
		{
			response.body = { result: `${args.expression} = '${this._fullDebugOutput[currentOutputLength]}'`, variablesReference: 0	};

			this._debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		this.scheduleExecution(()=>this.evaluateRequestFinalize(response, args, currentOutputLength));
	}

	private removePrompt(line : string): string{
		if (line.indexOf("bashdb<") == 0) {
			return line.substr(line.indexOf("> ") + 2);
		}

		return line;
	}

	private promptReached(currentOutputLength:number) : boolean{
		return this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == BashDebugSession.END_MARKER;
	}

	private processDebugTerminalOutput(sendOutput: boolean): void {

		this._debuggerProcess.stdio[3].on('data', (data) => {
			var list = data.toString().split("\n", -1);
			var fullLine = `${this._fullDebugOutput.pop()}${list.shift()}`;
			this._fullDebugOutput.push(this.removePrompt(fullLine));
			list.forEach(l => this._fullDebugOutput.push(this.removePrompt(l)));
		})
	}

	private scheduleExecution(callback: (...args: any[]) => void) : void {
		if (!this._debuggerExecutableClosing) {
			setTimeout(() => callback(), this._responsivityFactor);
		}
	}
}

DebugSession.run(BashDebugSession);
