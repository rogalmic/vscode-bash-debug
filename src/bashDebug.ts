import {
	Logger, logger,
	DebugSession, LoggingDebugSession,
	InitializedEvent, TerminatedEvent, StoppedEvent, OutputEvent,
	Thread, StackFrame, Scope, Source, Breakpoint
} from 'vscode-debugadapter';
import { DebugProtocol } from 'vscode-debugprotocol';
import { ChildProcess } from 'child_process';
import { basename, normalize, join, isAbsolute } from 'path';
import * as fs from 'fs';
import { validatePath } from './bashRuntime';
import { getWSLPath, reverseWSLPath, escapeCharactersInBashdbArg, getWSLLauncherPath } from './handlePath';
import { EventSource } from './eventSource';
import { spawnBashScript } from './spawnBash';
import { parse } from 'shell-quote'

export interface LaunchRequestArguments extends DebugProtocol.LaunchRequestArguments {

	// Non-optional arguments are guaranteed to be defined in extension.ts: resolveDebugConfiguration().
	argsString: string;
	args: string[];
	env: object;
	cwd: string;
	cwdEffective: string;
	program: string;
	programEffective: string;
	pathBash: string;
	pathBashdb: string;
	pathBashdbLib: string;
	pathCat: string;
	pathMkfifo: string;
	pathPkill: string;
	terminalKind?: 'integrated' | 'external' | 'debugConsole';
	showDebugOutput?: boolean;
	/** enable logging the Debug Adapter Protocol */
	trace?: boolean;
}

export class BashDebugSession extends LoggingDebugSession {

	private static THREAD_ID = 42;
	private static END_MARKER = "############################################################";

	private launchArgs: LaunchRequestArguments;

	private proxyProcess: ChildProcess;

	private currentBreakpointIds = new Map<string, Array<number>>();
	private proxyData = new Map<string, string>();

	private fullDebugOutput = [""];
	private fullDebugOutputIndex = 0;

	private debuggerExecutableBusy = false;
	private debuggerExecutableClosing = false;

	private outputEventSource = new EventSource();

	private debuggerProcessParentId = -1;

	public constructor() {
		super("bash-debug.txt");
		this.setDebuggerLinesStartAt1(true);
		this.setDebuggerColumnsStartAt1(true);
	}

	protected initializeRequest(response: DebugProtocol.InitializeResponse, _args: DebugProtocol.InitializeRequestArguments): void {

		response.body = response.body || {};

		response.body.supportsConditionalBreakpoints = true;
		response.body.supportsConfigurationDoneRequest = false;
		response.body.supportsEvaluateForHovers = true;
		response.body.supportsStepBack = false;
		response.body.supportsSetVariable = false;
		this.sendResponse(response);
	}

	protected disconnectRequest(response: DebugProtocol.DisconnectResponse, _args: DebugProtocol.DisconnectArguments): void {

		this.releaseDebugger();

		spawnBashScript(`${this.launchArgs.pathPkill} -KILL -P "${this.debuggerProcessParentId}"; ${this.launchArgs.pathPkill} -TERM -P "${this.proxyData["PROXYID"]}"`,
			this.launchArgs.pathBash,
			data => this.sendEvent(new OutputEvent(`${data}`, 'console')));

		this.proxyProcess.on("exit", () => {
			this.debuggerExecutableClosing = true;
			this.sendResponse(response);
		});
	}

	protected async launchRequest(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): Promise<void> {

		this.launchArgs = args;

		logger.setup(args.trace ? Logger.LogLevel.Verbose : Logger.LogLevel.Stop, false);

		if (process.platform === "win32") {
			args.cwdEffective = `${getWSLPath(args.cwd)}`;
			args.programEffective = `${getWSLPath(args.program)}`;
		}
		else {
			args.cwdEffective = args.cwd;
			args.programEffective = args.program;
		}

		const errorMessage = validatePath(
			args.cwdEffective, args.pathBash, args.pathBashdb, args.pathCat, args.pathMkfifo, args.pathPkill);

		if (errorMessage !== "") {
			response.success = false;
			response.message = errorMessage;
			this.sendResponse(response);
			return;
		}

		const fifo_path = "/tmp/vscode-bash-debug-fifo-" + (Math.floor(Math.random() * 10000) + 10000);

		// http://tldp.org/LDP/abs/html/io-redirection.html
		this.proxyProcess = spawnBashScript(
			`function cleanup()
		{
			exit_code=$?
			trap '' ERR SIGINT SIGTERM EXIT
			exec 4>&-
			rm "${fifo_path}_in"
			rm "${fifo_path}"
			exit $exit_code
		}
		echo "::PROXYID::$$" >&2
		trap 'cleanup' ERR SIGINT SIGTERM EXIT
		mkfifo "${fifo_path}"
		mkfifo "${fifo_path}_in"

		"${args.pathCat}" "${fifo_path}" &
		exec 4>"${fifo_path}"
		"${args.pathCat}" >"${fifo_path}_in"`
				.replace("\r", ""),
			this.launchArgs.pathBash,
			(data, category) => {
				if (args.showDebugOutput || category === "console") {
					this.sendEvent(new OutputEvent(`${data}`, category));
				}
			});

		this.proxyProcess.stdin!.write(`examine Debug environment: bash_ver=$BASH_VERSION, bashdb_ver=$_Dbg_release, program=$0, args=$*\nprint "$PPID"\nhandle INT stop\nprint '${BashDebugSession.END_MARKER}'\n`);

		let envVars = Object.keys(this.launchArgs.env)
			.map(e => `export ${e}='${this.launchArgs.env[e]}';`)
			.reduce((prev, next) => prev + next, ``);

		const command = this.joinCommands(
			`${envVars}cd "${args.cwdEffective}"`,
			`while [[ ! -p "${fifo_path}" ]]; do sleep 0.25; done`,
			`"${args.pathBash}" "${args.pathBashdb}" --quiet --tty "${fifo_path}" --tty_in "${fifo_path}_in" --library "${args.pathBashdbLib}" -- "${args.programEffective}" ${args.args.map(e => `"` + e.replace(`"`, `\\\"`) + `"`).join(` `)} ${args.argsString ? parse(args.argsString).map(e => `"` + e.replace(`"`, `\\\"`) + `"`).join(` `) : ""}`);

		if (this.launchArgs.terminalKind === "debugConsole" || this.launchArgs.terminalKind === undefined) {
			spawnBashScript(
				command,
				this.launchArgs.pathBash,
				(data, category) => this.sendEvent(new OutputEvent(`${data}`, category)));
		}
		else {
			const currentShell = (process.platform === "win32") ? getWSLLauncherPath(true) : args.pathBash;
			const optionalBashPathArgument = (currentShell !== args.pathBash) ? args.pathBash : "";
			const termArgs: DebugProtocol.RunInTerminalRequestArguments = {
				kind: this.launchArgs.terminalKind,
				title: "Bash Debug Console",
				cwd: ".",
				args: [currentShell, optionalBashPathArgument, `-c`, command].filter(arg => arg !== ""),
			};

			this.runInTerminalRequest(termArgs, 10000, (response) => {
				if (!response.success) {
					this.sendEvent(new OutputEvent(`${JSON.stringify(response)}`, 'console'));
				}
			});
		}

		await this.onDebuggerAvailable();

		this.processDebugTerminalOutput();
		this.launchRequestFinalize(response, args);
	}

	private joinCommands(...cmd: string[]): string {
		return cmd.join(`; `);
	}

	private async launchRequestFinalize(response: DebugProtocol.LaunchResponse, _args: LaunchRequestArguments): Promise<void> {

		while (await this.onNextDebuggerOutput()) {
			for (let i = 0; i < this.fullDebugOutput.length; i++) {
				if (this.fullDebugOutput[i] === BashDebugSession.END_MARKER) {

					this.debuggerProcessParentId = parseInt(this.fullDebugOutput[i - 1]);
					BashDebugSession.END_MARKER = `${this.debuggerProcessParentId}${BashDebugSession.END_MARKER}`;
					this.sendResponse(response);
					this.sendEvent(new OutputEvent(`Sending InitializedEvent`, 'telemetry'));
					this.releaseDebugger();
					this.sendEvent(new InitializedEvent());

					return;
				}
			}
		}
	}

	protected async setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): Promise<void> {

		await this.onDebuggerAvailable();

		if (!args.source.path) {
			this.sendEvent(new OutputEvent("Error: setBreakPointsRequest(): args.source.path is undefined.", 'console'));
			return;
		}

		let sourcePath = (process.platform === "win32") ? getWSLPath(args.source.path) : args.source.path;

		if (sourcePath !== undefined) {
			sourcePath = escapeCharactersInBashdbArg(sourcePath);
		}

		let setBreakpointsCommand = ``;

		if (this.currentBreakpointIds[args.source.path] === undefined) {
			this.currentBreakpointIds[args.source.path] = [];
			setBreakpointsCommand += `load ${sourcePath}\n`;
		}

		setBreakpointsCommand += (this.currentBreakpointIds[args.source.path].length > 0)
			? `print 'delete <${this.currentBreakpointIds[args.source.path].join(" ")}>'\ndelete ${this.currentBreakpointIds[args.source.path].join(" ")}\nyes\n`
			: ``;

		if (args.breakpoints) {
			args.breakpoints.forEach((b) => { setBreakpointsCommand += `print 'break <${sourcePath}:${b.line} ${b.condition ? b.condition : ""}> '\nbreak ${sourcePath}:${b.line} ${b.condition ? escapeCharactersInBashdbArg(b.condition) : ""}\n`; });
		}

		if (this.launchArgs.showDebugOutput) {
			setBreakpointsCommand += `info files\ninfo breakpoints\n`;
		}

		const currentLine = this.fullDebugOutput.length;
		this.proxyProcess.stdin!.write(`${setBreakpointsCommand}print '${BashDebugSession.END_MARKER}'\n`);
		this.setBreakPointsRequestFinalize(response, args, currentLine);
	}

	private async setBreakPointsRequestFinalize(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments, currentOutputLength: number): Promise<void> {

		if (!args.source.path) {
			this.sendEvent(new OutputEvent("Error: setBreakPointsRequestFinalize(): args.source.path is undefined.", 'console'));
			return;
		}

		while (await this.onNextDebuggerOutput()) {
			if (this.promptReached(currentOutputLength)) {
				this.currentBreakpointIds[args.source.path] = [];
				const breakpoints = new Array<Breakpoint>();

				for (let i = currentOutputLength; i < this.fullDebugOutput.length - 2; i++) {

					if (this.fullDebugOutput[i - 1].indexOf("break <") === 0 && this.fullDebugOutput[i - 1].indexOf("> ") > 0) {

						const lineNodes = this.fullDebugOutput[i].split(" ");
						const bp = <DebugProtocol.Breakpoint>new Breakpoint(true, this.convertDebuggerLineToClient(parseInt(lineNodes[lineNodes.length - 1].replace(".", ""))));
						bp.id = parseInt(lineNodes[1]);
						breakpoints.push(bp);
						this.currentBreakpointIds[args.source.path].push(bp.id);
					}
				}

				response.body = { breakpoints: breakpoints };
				this.releaseDebugger();
				this.sendResponse(response);
				return;
			}
		}
	}

	protected async threadsRequest(response: DebugProtocol.ThreadsResponse): Promise<void> {

		response.body = { threads: [new Thread(BashDebugSession.THREAD_ID, "Bash thread")] };
		this.sendResponse(response);
	}

	protected async stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): Promise<void> {

		await this.onDebuggerAvailable();

		const currentLine = this.fullDebugOutput.length;
		this.proxyProcess.stdin!.write(`print backtrace\nbacktrace\nprint '${BashDebugSession.END_MARKER}'\n`);
		this.stackTraceRequestFinalize(response, args, currentLine);
	}

	private async stackTraceRequestFinalize(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments, currentOutputLength: number): Promise<void> {

		while (await this.onNextDebuggerOutput()) {
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

						frameSourcePath = reverseWSLPath(frameSourcePath);
					}

					frameSourcePath = isAbsolute(frameSourcePath) ? frameSourcePath : normalize(join(this.launchArgs.cwd, frameSourcePath));

					frames.push(new StackFrame(
						frameIndex,
						frameText,
						fs.existsSync(frameSourcePath) ? new Source(basename(frameSourcePath), this.convertDebuggerPathToClient(frameSourcePath), undefined, undefined, 'bash-adapter-data') : undefined,
						this.convertDebuggerLineToClient(frameLine)
					));
				}

				if (frames.length > 0) {
					this.sendEvent(new OutputEvent(`Execution breaks at '${frames[0].name}'\n`, 'telemetry'));
				}

				const totalFrames = this.fullDebugOutput.length - currentOutputLength - 1;

				const startFrame = typeof args.startFrame === 'number' ? args.startFrame : 0;
				const maxLevels = typeof args.levels === 'number' ? args.levels : 100;
				frames = frames.slice(startFrame, Math.min(startFrame + maxLevels, frames.length));

				response.body = { stackFrames: frames, totalFrames: totalFrames };
				this.releaseDebugger();
				this.sendResponse(response);
				return;
			}
		}
	}

	protected async scopesRequest(response: DebugProtocol.ScopesResponse, _args: DebugProtocol.ScopesArguments): Promise<void> {

		const scopes = [new Scope("Local", this.fullDebugOutputIndex, false)];
		response.body = { scopes: scopes };
		this.sendResponse(response);
	}

	protected async variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): Promise<void> {

		await this.onDebuggerAvailable();

		let getVariablesCommand = `info program\n`;
		const count = typeof args.count === 'number' ? args.count : 100;
		const start = typeof args.start === 'number' ? args.start : 0;
		let variableDefinitions = ["$PWD", "$? \\\# from '$_Dbg_last_bash_command'"];
		variableDefinitions = variableDefinitions.slice(start, Math.min(start + count, variableDefinitions.length));

		variableDefinitions.forEach((v) => { getVariablesCommand += `print 'examine <${v}> '\nexamine ${v}\n`; });

		const currentLine = this.fullDebugOutput.length;
		this.proxyProcess.stdin!.write(`${getVariablesCommand}print '${BashDebugSession.END_MARKER}'\n`);
		this.variablesRequestFinalize(response, args, currentLine);
	}

	private async variablesRequestFinalize(response: DebugProtocol.VariablesResponse, _args: DebugProtocol.VariablesArguments, currentOutputLength: number): Promise<void> {

		while (await this.onNextDebuggerOutput()) {
			if (this.promptReached(currentOutputLength)) {
				let variables: any[] = [];

				for (let i = currentOutputLength; i < this.fullDebugOutput.length - 2; i++) {

					if (this.fullDebugOutput[i - 1].indexOf("examine <") === 0 && this.fullDebugOutput[i - 1].indexOf("> ") > 0) {

						variables.push({
							name: `${this.fullDebugOutput[i - 1].replace("examine <", "").replace("> ", "").split('#')[0]}`,
							type: "string",
							value: this.fullDebugOutput[i],
							variablesReference: 0
						});
					}
				}

				response.body = { variables: variables };
				this.releaseDebugger();
				this.sendResponse(response);
				return;
			}
		}
	}

	protected async continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): Promise<void> {

		await this.onDebuggerAvailable();

		const currentLine = this.fullDebugOutput.length;
		this.proxyProcess.stdin!.write(`print continue\ncontinue\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.continueRequestFinalize(response, args, currentLine);

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private async continueRequestFinalize(_response: DebugProtocol.ContinueResponse, _args: DebugProtocol.ContinueArguments, currentOutputLength: number): Promise<void> {

		while (await this.onNextDebuggerOutput()) {
			if (this.promptReached(currentOutputLength)) {
				this.releaseDebugger();
				return;
			}
		}
	}

	// bashdb doesn't support reverse execution
	// protected reverseContinueRequest(response: DebugProtocol.ReverseContinueResponse, args: DebugProtocol.ReverseContinueArguments) : void {
	// }

	protected async nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): Promise<void> {

		await this.onDebuggerAvailable();

		const currentLine = this.fullDebugOutput.length;
		this.proxyProcess.stdin!.write(`print next\nnext\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.nextRequestFinalize(response, args, currentLine);

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private async nextRequestFinalize(_response: DebugProtocol.NextResponse, _args: DebugProtocol.NextArguments, currentOutputLength: number): Promise<void> {

		while (await this.onNextDebuggerOutput()) {

			if (this.promptReached(currentOutputLength)) {
				this.releaseDebugger();
				return;
			}
		}
	}

	protected async stepInRequest(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments): Promise<void> {

		await this.onDebuggerAvailable();

		const currentLine = this.fullDebugOutput.length;
		this.proxyProcess.stdin!.write(`print step\nstep\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.stepInRequestFinalize(response, args, currentLine);

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private async stepInRequestFinalize(_response: DebugProtocol.StepInResponse, _args: DebugProtocol.StepInArguments, currentOutputLength: number): Promise<void> {

		while (await this.onNextDebuggerOutput()) {

			if (this.promptReached(currentOutputLength)) {
				this.releaseDebugger();
				return;
			}
		}
	}

	protected async stepOutRequest(response: DebugProtocol.StepOutResponse, args: DebugProtocol.StepOutArguments): Promise<void> {

		await this.onDebuggerAvailable();

		const currentLine = this.fullDebugOutput.length;
		this.proxyProcess.stdin!.write(`print finish\nfinish\nprint '${BashDebugSession.END_MARKER}'\n`);

		this.stepOutRequestFinalize(response, args, currentLine);

		// NOTE: do not wait for step to finish
		this.sendResponse(response);
	}

	private async stepOutRequestFinalize(_response: DebugProtocol.StepOutResponse, _args: DebugProtocol.StepOutArguments, currentOutputLength: number): Promise<void> {

		while (await this.onNextDebuggerOutput()) {

			if (this.promptReached(currentOutputLength)) {
				this.releaseDebugger();
				return;
			}
		}
	}

	// bashdb doesn't support reverse execution
	// protected stepBackRequest(response: DebugProtocol.StepBackResponse, args: DebugProtocol.StepBackArguments): void {
	// }

	protected async evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): Promise<void> {

		await this.onDebuggerAvailable();

		const currentLine = this.fullDebugOutput.length;
		let expression = (args.context === "hover") ? `${args.expression.replace(/['"]+/g, "")}` : `${args.expression}`;
		expression = escapeCharactersInBashdbArg(expression);
		this.proxyProcess.stdin!.write(`print 'examine <${expression}>'\nexamine ${expression}\nprint '${BashDebugSession.END_MARKER}'\n`);
		this.evaluateRequestFinalize(response, args, currentLine);
	}

	private async evaluateRequestFinalize(response: DebugProtocol.EvaluateResponse, _args: DebugProtocol.EvaluateArguments, currentOutputLength: number): Promise<void> {

		while (await this.onNextDebuggerOutput()) {

			if (this.promptReached(currentOutputLength)) {
				response.body = { result: `'${this.fullDebugOutput[currentOutputLength]}'`, variablesReference: 0 };

				this.releaseDebugger();
				this.sendResponse(response);
				return;
			}
		}
	}

	protected async pauseRequest(response: DebugProtocol.PauseResponse, args: DebugProtocol.PauseArguments): Promise<void> {
		if (args.threadId === BashDebugSession.THREAD_ID) {
			spawnBashScript(`${this.launchArgs.pathPkill} -INT -P ${this.debuggerProcessParentId} -f bashdb`,
				this.launchArgs.pathBash,
				data => this.sendEvent(new OutputEvent(`${data}`, 'console')))
				.on("exit", () => this.sendResponse(response));
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

		this.proxyProcess.stdio[2]!.on('data', (data) => {
			const list = data.toString().split("\n");
			list.forEach(l => {
				let nodes = l.split("::");
				if (nodes.length === 3) {
					this.proxyData[nodes[1]] = nodes[2];
				}
			});
		});

		this.outputEventSource.schedule(() => {
			for (; this.fullDebugOutputIndex < this.fullDebugOutput.length - 1; this.fullDebugOutputIndex++) {
				const line = this.fullDebugOutput[this.fullDebugOutputIndex];

				if (line.indexOf("(") === 0 && line.indexOf("):") === line.length - 2) {
					this.sendEvent(new OutputEvent(`Sending StoppedEvent`, 'telemetry'));
					this.sendEvent(new StoppedEvent("break", BashDebugSession.THREAD_ID));
				}
				else if (line.indexOf("Program received signal ") === 0) {
					this.sendEvent(new OutputEvent(`Sending StoppedEvent`, 'telemetry'));
					this.sendEvent(new StoppedEvent("break", BashDebugSession.THREAD_ID));
				}
				else if (line.indexOf("Debugged program terminated") === 0) {
					this.proxyProcess.stdin!.write(`\nq\n`);
					this.sendEvent(new OutputEvent(`Sending TerminatedEvent`, 'telemetry'));
					this.sendEvent(new TerminatedEvent());
				}
			}
		});

		this.proxyProcess.stdio[1]!.on('data', (data) => {

			const list = data.toString().split("\n", -1);
			const fullLine = `${this.fullDebugOutput.pop()}${list.shift()}`;
			this.fullDebugOutput.push(this.removePrompt(fullLine));
			list.forEach(l => this.fullDebugOutput.push(this.removePrompt(l)));
			this.outputEventSource.setEvent();
		});
	}

	private async onDebuggerAvailable(): Promise<void> {

		while (this.debuggerExecutableBusy) {
			await this.outputEventSource.onEvent();
		}

		this.debuggerExecutableBusy = true;
	}

	private async onNextDebuggerOutput(): Promise<boolean> {

		await this.outputEventSource.onEvent();

		return !this.debuggerExecutableClosing;
	}

	private async releaseDebugger(): Promise<void> {

		this.debuggerExecutableBusy = false;
		this.outputEventSource.setEvent();
	}
}

DebugSession.run(BashDebugSession);
