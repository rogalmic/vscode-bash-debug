import {
	Logger, logger,
	DebugSession, LoggingDebugSession,
	// @ts-ignore: error TS6133: 'BreakpointEvent' is declared but its value is never read.
	InitializedEvent, TerminatedEvent, StoppedEvent, BreakpointEvent, OutputEvent,
	// @ts-ignore: error TS6133: 'Handles' is declared but its value is never read.
	Thread, StackFrame, Scope, Source, Handles, Breakpoint
} from 'vscode-debugadapter';
import { DebugProtocol } from 'vscode-debugprotocol';
import { ChildProcess, spawn } from 'child_process';
import { basename } from 'path';
import { validatePath } from './bashRuntime';
import { getWSLPath } from './handlePath';

export interface LaunchRequestArguments extends DebugProtocol.LaunchRequestArguments {

	// Non-optional arguments are guaranteed to be defined in extension.ts: resolveDebugConfiguration().
	args: string[];
	cwd: string;
	program: string;
	pathBash: string;
	pathBashdb: string;
	pathCat: string;
	pathMkfifo: string;
	pathPkill: string;
	showDebugOutput?: boolean;
	/** enable logging the Debug Adapter Protocol */
	trace?: boolean;
}

export class BashDebugSession extends LoggingDebugSession {

	private static THREAD_ID = 42;
	private static END_MARKER = "############################################################";

	private launchArgs: LaunchRequestArguments;

	private debuggerProcess: ChildProcess;

	private currentBreakpointIds = new Map<string, Array<number>>();

	private fullDebugOutput = [""];
	private fullDebugOutputIndex = 0;

	private debuggerExecutableBusy = false;
	private debuggerExecutableClosing = false;

	private responsivityFactor = 5;

	private debuggerProcessParentId = -1;

	// https://github.com/Microsoft/BashOnWindows/issues/1489
	private debugPipeIndex = (process.platform === "win32") ? 2 : 3;

	public constructor() {
		super("bash-debug.txt");
		this.setDebuggerLinesStartAt1(true);
		this.setDebuggerColumnsStartAt1(true);
	}

	protected initializeRequest(response: DebugProtocol.InitializeResponse, args: DebugProtocol.InitializeRequestArguments): void {

		response.body = response.body || {};

		response.body.supportsConditionalBreakpoints = false;
		response.body.supportsConfigurationDoneRequest = false;
		response.body.supportsEvaluateForHovers = true;
		response.body.supportsStepBack = false;
		response.body.supportsSetVariable = false;
		this.sendResponse(response);
	}

	protected disconnectRequest(response: DebugProtocol.DisconnectResponse, args: DebugProtocol.DisconnectArguments): void {
		this.debuggerExecutableBusy = false;

		this.debuggerProcess.on("exit", () => {
			this.debuggerExecutableClosing = true;
			this.sendResponse(response)
		});

		spawn("bash", ["-c", `${this.launchArgs.pathPkill} -KILL -P ${this.debuggerProcessParentId}`]);
	}

	protected launchRequest(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		this.launchArgs = args;

		logger.setup(args.trace ? Logger.LogLevel.Verbose : Logger.LogLevel.Stop, false);

		if (process.platform === "win32") {
			args.cwd = `${getWSLPath(args.cwd)}`;
			args.program = `${getWSLPath(args.program)}`;
		}

		{
			const errorMessage = validatePath(
				args.cwd, args.pathBash, args.pathBashdb, args.pathCat, args.pathMkfifo, args.pathPkill);

			if (errorMessage !== "") {
				response.success = false;
				response.message = errorMessage;
				this.sendResponse(response);
				return;
			}
		}

		const fifo_path = "/tmp/vscode-bash-debug-fifo-" + (Math.floor(Math.random() * 10000) + 10000);

		// TODO: treat whitespace in args.args:
		//       i.e. at this moment, ["arg0", "arg1 with space"] will be expanded to "arg0 arg1 with space"
		// use fifo, because --tty '&1' does not work properly for subshell (when bashdb spawns - $() )
		// when this is fixed in bashdb, use &1
		this.debuggerProcess = spawn(args.pathBash, ["-c", `

			# http://tldp.org/LDP/abs/html/io-redirection.html

			function cleanup()
			{
				exit_code=$?
				trap '' ERR SIGINT SIGTERM EXIT
				exec 4>&-
				rm "${fifo_path}";
				exit $exit_code;
			}
			trap 'cleanup' ERR SIGINT SIGTERM EXIT

			mkfifo "${fifo_path}"
			${args.pathCat} "${fifo_path}" >&${this.debugPipeIndex} &
			exec 4>"${fifo_path}" 		# Keep open for writing, bashdb seems close after every write.
			cd ${args.cwd}
			${args.pathCat} | ${args.pathBashdb} --quiet --tty "${fifo_path}" -- "${args.program}" ${args.args.join(" ")}
			`
		], { stdio: ["pipe", "pipe", "pipe", "pipe"] });

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

		for (let i = 0; i < this.fullDebugOutput.length; i++) {
			if (this.fullDebugOutput[i] === BashDebugSession.END_MARKER) {

				this.debuggerProcessParentId = parseInt(this.fullDebugOutput[i - 1]);
				this.sendResponse(response);
				this.sendEvent(new OutputEvent(`Sending InitializedEvent`, 'telemetry'));
				this.sendEvent(new InitializedEvent());

				const interval = setInterval((data) => {
					for (; this.fullDebugOutputIndex < this.fullDebugOutput.length - 1; this.fullDebugOutputIndex++) {
						const line = this.fullDebugOutput[this.fullDebugOutputIndex];

						if (line.indexOf("(/") === 0 && line.indexOf("):") === line.length - 2) {
							this.sendEvent(new OutputEvent(`Sending StoppedEvent`, 'telemetry'));
							this.sendEvent(new StoppedEvent("break", BashDebugSession.THREAD_ID));
						}
						else if (line.indexOf("terminated") > 0) {
							clearInterval(interval);
							this.debuggerProcess.stdin.write(`\nq\n`);
							this.sendEvent(new OutputEvent(`Sending TerminatedEvent`, 'telemetry'));
							this.sendEvent(new TerminatedEvent());
						}
					}
				}, this.responsivityFactor);
				return;
			}
		}

		this.scheduleExecution(() => this.launchRequestFinalize(response, args));
	}


	protected setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): void {

		if (this.debuggerExecutableBusy) {
			this.scheduleExecution(() => this.setBreakPointsRequest(response, args));
			return;
		}

		if (!args.source.path) {
			this.sendEvent(new OutputEvent("Error: setBreakPointsRequest(): args.source.path is undefined.", 'stderr'));
			return;
		}

		if (!this.currentBreakpointIds[args.source.path]) {
			this.currentBreakpointIds[args.source.path] = [];
		}

		const sourcePath = (process.platform === "win32") ? this.getLinuxPathFromWindows(args.source.path) : args.source.path;

		let setBreakpointsCommand = `print 'delete <${this.currentBreakpointIds[args.source.path].join(" ")}>'\ndelete ${this.currentBreakpointIds[args.source.path].join(" ")}\nload ${sourcePath}\n`;
		if (args.breakpoints) {
			args.breakpoints.forEach((b) => { setBreakpointsCommand += `print ' <${sourcePath}:${b.line}> '\nbreak ${sourcePath}:${b.line}\n` });
		}

		this.debuggerExecutableBusy = true;
		const currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`${setBreakpointsCommand}print '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(() => this.setBreakPointsRequestFinalize(response, args, currentLine));
	}

	private setBreakPointsRequestFinalize(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments, currentOutputLength: number): void {

		if (!args.source.path) {
			this.sendEvent(new OutputEvent("Error: setBreakPointsRequestFinalize(): args.source.path is undefined.", 'stderr'));
			return;
		}

		if (this.promptReached(currentOutputLength)) {
			this.currentBreakpointIds[args.source.path] = [];
			const breakpoints = new Array<Breakpoint>();

			for (let i = currentOutputLength; i < this.fullDebugOutput.length - 2; i++) {

				if (this.fullDebugOutput[i - 1].indexOf(" <") === 0 && this.fullDebugOutput[i - 1].indexOf("> ") > 0) {

					const lineNodes = this.fullDebugOutput[i].split(" ");
					const bp = <DebugProtocol.Breakpoint>new Breakpoint(true, this.convertDebuggerLineToClient(parseInt(lineNodes[lineNodes.length - 1].replace(".", ""))));
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

		this.scheduleExecution(() => this.setBreakPointsRequestFinalize(response, args, currentOutputLength));
	}

	protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {

		response.body = { threads: [new Thread(BashDebugSession.THREAD_ID, "Bash thread")] };
		this.sendResponse(response);
	}

	protected stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {

		if (this.debuggerExecutableBusy) {
			this.scheduleExecution(() => this.stackTraceRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		const currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print backtrace\nbacktrace\nprint '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(() => this.stackTraceRequestFinalize(response, args, currentLine));
	}

	private stackTraceRequestFinalize(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments, currentOutputLength: number): void {

		if (this.promptReached(currentOutputLength)) {
			const lastStackLineIndex = this.fullDebugOutput.length - 3;

			let frames = new Array<StackFrame>();
			for (let i = currentOutputLength; i <= lastStackLineIndex; i++) {
				const lineContent = this.fullDebugOutput[i];
				const frameIndex = parseInt(lineContent.substr(2, 2));
				const frameText = lineContent;
				let frameSourcePath = lineContent.substr(lineContent.lastIndexOf("`") + 1, lineContent.lastIndexOf("'") - lineContent.lastIndexOf("`") - 1);
				const frameLine = parseInt(lineContent.substr(lineContent.lastIndexOf(" ")));

				if ((process.platform === "win32")) {
					frameSourcePath = this.getWindowsPathFromLinux(frameSourcePath);
				}

				frames.push(new StackFrame(
					frameIndex,
					frameText,
					new Source(basename(frameSourcePath), this.convertDebuggerPathToClient(frameSourcePath), undefined, undefined, 'bash-adapter-data'),
					this.convertDebuggerLineToClient(frameLine)
				));
			}

			const totalFrames = this.fullDebugOutput.length - currentOutputLength - 1;

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

		const scopes = [new Scope("Local", this.fullDebugOutputIndex, false)];
		response.body = { scopes: scopes };
		this.sendResponse(response);
	}

	protected variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): void {

		if (this.debuggerExecutableBusy) {
			this.scheduleExecution(() => this.variablesRequest(response, args));
			return;
		}

		let getVariablesCommand = `info program\n`;

		const count = typeof args.count === 'number' ? args.count : 100;
		const start = typeof args.start === 'number' ? args.start : 0;
		let variableDefinitions = ["PWD", "EUID", "#", "0", "-"];
		variableDefinitions = variableDefinitions.slice(start, Math.min(start + count, variableDefinitions.length));

		variableDefinitions.forEach((v) => { getVariablesCommand += `print ' <$${v}> '\nexamine $${v}\n` });

		this.debuggerExecutableBusy = true;
		const currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`${getVariablesCommand}print '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(() => this.variablesRequestFinalize(response, args, currentLine));
	}

	private variablesRequestFinalize(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments, currentOutputLength: number): void {

		if (this.promptReached(currentOutputLength)) {
			let variables: any[] = [];

			for (let i = currentOutputLength; i < this.fullDebugOutput.length - 2; i++) {

				if (this.fullDebugOutput[i - 1].indexOf(" <") === 0 && this.fullDebugOutput[i - 1].indexOf("> ") > 0) {

					variables.push({
						name: `${this.fullDebugOutput[i - 1].replace(" <", "").replace("> ", "")}`,
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

		this.scheduleExecution(() => this.variablesRequestFinalize(response, args, currentOutputLength));
	}

	protected continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {

		if (this.debuggerExecutableBusy) {
			this.scheduleExecution(() => this.continueRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		const currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print continue\ncontinue\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(() => this.continueRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private continueRequestFinalize(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments, currentOutputLength: number): void {

		if (this.promptReached(currentOutputLength)) {
			this.debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(() => this.continueRequestFinalize(response, args, currentOutputLength));
	}

	// bashdb doesn't support reverse execution
	// protected reverseContinueRequest(response: DebugProtocol.ReverseContinueResponse, args: DebugProtocol.ReverseContinueArguments) : void {
	// }

	protected nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {

		if (this.debuggerExecutableBusy) {
			this.scheduleExecution(() => this.nextRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		const currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print next\nnext\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(() => this.nextRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private nextRequestFinalize(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments, currentOutputLength: number): void {

		if (this.promptReached(currentOutputLength)) {
			this.debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(() => this.nextRequestFinalize(response, args, currentOutputLength));
	}

	protected stepInRequest(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments): void {

		if (this.debuggerExecutableBusy) {
			this.scheduleExecution(() => this.stepInRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		const currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print step\nstep\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(() => this.stepInRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private stepInRequestFinalize(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments, currentOutputLength: number): void {
		if (this.promptReached(currentOutputLength)) {
			this.debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(() => this.stepInRequestFinalize(response, args, currentOutputLength));
	}

	protected stepOutRequest(response: DebugProtocol.StepOutResponse, args: DebugProtocol.StepOutArguments): void {

		if (this.debuggerExecutableBusy) {
			this.scheduleExecution(() => this.stepOutRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		const currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print finish\nfinish\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.scheduleExecution(() => this.stepOutRequestFinalize(response, args, currentLine));

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private stepOutRequestFinalize(response: DebugProtocol.StepOutResponse, args: DebugProtocol.StepOutArguments, currentOutputLength: number): void {
		if (this.promptReached(currentOutputLength)) {
			this.debuggerExecutableBusy = false;
			return;
		}

		this.scheduleExecution(() => this.stepOutRequestFinalize(response, args, currentOutputLength));
	}

	// bashdb doesn't support reverse execution
	// protected stepBackRequest(response: DebugProtocol.StepBackResponse, args: DebugProtocol.StepBackArguments): void {
	// }

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {

		if (this.debuggerProcess === null) {
			response.body = { result: `${args.expression} = ''`, variablesReference: 0 };
			this.debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		if (this.debuggerExecutableBusy) {
			this.scheduleExecution(() => this.evaluateRequest(response, args));
			return;
		}

		this.debuggerExecutableBusy = true;
		const currentLine = this.fullDebugOutput.length;
		this.debuggerProcess.stdin.write(`print 'examine <${args.expression}>'\nexamine ${args.expression.replace("\"", "")}\nprint '${BashDebugSession.END_MARKER}'\n`);
		this.scheduleExecution(() => this.evaluateRequestFinalize(response, args, currentLine));
	}

	private evaluateRequestFinalize(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments, currentOutputLength: number): void {

		if (this.promptReached(currentOutputLength)) {
			response.body = { result: `'${this.fullDebugOutput[currentOutputLength]}'`, variablesReference: 0 };

			this.debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		this.scheduleExecution(() => this.evaluateRequestFinalize(response, args, currentOutputLength));
	}

	protected pauseRequest(response: DebugProtocol.PauseResponse, args: DebugProtocol.PauseArguments): void {
		if (args.threadId === BashDebugSession.THREAD_ID) {
			spawn("bash", ["-c", `${this.launchArgs.pathPkill} -INT -P ${this.debuggerProcessParentId} -f bashdb`]).on("exit", () => this.sendResponse(response));
			return;
		}

		response.success = false;
		this.sendResponse(response);
	}

	private removePrompt(line: string): string {
		if (line.indexOf("bashdb<") === 0) {
			return line.substr(line.indexOf("> ") + 2);
		}

		return line;
	}

	private promptReached(currentOutputLength: number): boolean {
		return this.fullDebugOutput.length > currentOutputLength && this.fullDebugOutput[this.fullDebugOutput.length - 2] === BashDebugSession.END_MARKER;
	}

	private processDebugTerminalOutput(): void {

		this.debuggerProcess.stdio[this.debugPipeIndex].on('data', (data) => {

			if (this.fullDebugOutput.length === 1 && data.indexOf("Reading ") === 0) {
				// Before debug run, there is no newline
				return;
			}

			const list = data.toString().split("\n", -1);
			const fullLine = `${this.fullDebugOutput.pop()}${list.shift()}`;
			this.fullDebugOutput.push(this.removePrompt(fullLine));
			list.forEach(l => this.fullDebugOutput.push(this.removePrompt(l)));
		})
	}

	private scheduleExecution(callback: (...args: any[]) => void): void {
		if (!this.debuggerExecutableClosing) {
			setTimeout(() => callback(), this.responsivityFactor);
		}
	}

	private getWindowsPathFromLinux(linuxPath: string): string {
		return linuxPath.substr("/mnt/".length, 1).toUpperCase() + ":" + linuxPath.substr("/mnt/".length + 1).split("/").join("\\");
	}

	private getLinuxPathFromWindows(windowsPath: string): string {
		return "/mnt/" + windowsPath.substr(0, 1).toLowerCase() + windowsPath.substr("X:".length).split("\\").join("/");
	}
}

DebugSession.run(BashDebugSession);
