/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

/// <reference types="es6-collections" />
/// <reference types="node" />

import {
	DebugSession,
	InitializedEvent, TerminatedEvent, StoppedEvent, BreakpointEvent, OutputEvent, Event,
	Thread, StackFrame, Scope, Source, Handles, Breakpoint
} from 'vscode-debugadapter';
import {DebugProtocol} from 'vscode-debugprotocol';
import {readFileSync} from 'fs';
import {basename} from 'path';
import * as ChildProcess from "child_process"


/**
 * This interface should always match the schema found in the mock-debug extension manifest.
 */
export interface LaunchRequestArguments extends DebugProtocol.LaunchRequestArguments {
	/** An absolute path to the program to debug. */
	program: string;
	/** Automatically stop target after launch. If not specified, target does not stop. */
	stopOnEntry?: boolean;
}

class BashDebugSession extends DebugSession {

	// we don't support multiple threads, so we can use a hardcoded ID for the default thread
	private static THREAD_ID = 1;

	private static BASHDB_PROMPT = "bashdb<";

	// since we want to send breakpoint events, we will assign an id to every event
	// so that the frontend can match events with breakpoints.
	private _breakpointId = 1000;

	// This is the next line that will be 'executed'
	private __currentLine = 0;
	private get _currentLine() : number {
		return this.__currentLine;
    }
	private set _currentLine(line: number) {
		this.__currentLine = line;
		this.sendEvent(new OutputEvent(`line: ${line}\n`));	// print current line on debug console
	}

	// the initial (and one and only) file we are 'debugging'
	private _sourceFile: string;

	// the contents (= lines) of the one and only file
	private _sourceLines = new Array<string>();

	// maps from sourceFile to array of Breakpoints
	private _breakPoints = new Map<string, DebugProtocol.Breakpoint[]>();

	private _variableHandles = new Handles<string>();

	private _fullDebugOutput = [""];

	private _debuggerExecutableBusy = false;


	/**
	 * Creates a new debug adapter that is used for one debug session.
	 * We configure the default implementation of a debug adapter here.
	 */
	public constructor() {
		super();

		// this debugger uses zero-based lines and columns
		this.setDebuggerLinesStartAt1(true);
		this.setDebuggerColumnsStartAt1(true);
	}

	/**
	 * The 'initialize' request is the first request called by the frontend
	 * to interrogate the features the debug adapter provides.
	 */
	protected initializeRequest(response: DebugProtocol.InitializeResponse, args: DebugProtocol.InitializeRequestArguments): void {

		this.sendEvent(new OutputEvent(`initializeRequest: ${args.adapterID}\n`));
		response.body.supportsConfigurationDoneRequest = false;
		response.body.supportsEvaluateForHovers = true;
		response.body.supportsStepBack = false;

		setTimeout(()=>this.initializeRequestFinalize(response, args), 0);
	}

	private initializeRequestFinalize(response: DebugProtocol.InitializeResponse, args: DebugProtocol.InitializeRequestArguments): void {

		this.sendResponse(response);
	}

	protected launchRequest(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		this.sendEvent(new OutputEvent(`launchRequest: ${args.program}\n`));

		this.process = ChildProcess.spawn("bashdb", ["--quiet", args.program]);

		this.process.stdout.on("data", (data) =>
		{
			this.sendEvent(new OutputEvent(`stdout: '${data}'\n`));

			var list = data.toString().split("\n", -1);

			//this.sendEvent(new OutputEvent(`TEST(${this._fullDebugOutput.length}): ${this._fullDebugOutput.join("=======")} \n`));

			for (var i=list.length-1; i>=0; i--)
			{
				try
				{
					if (list[i].indexOf("(/") == 0)
					{
						var res = list[i].replace("(", "").replace(")", "");
						this.sendEvent(new OutputEvent(`line: ${res}\n`));
						this._currentLine = parseInt(res.split(":", -1)[1]);
						this._sourceFile = res.split(":", -1)[0];
						this.sendEvent(new StoppedEvent("break", BashDebugSession.THREAD_ID));
					}
					else if (list[i].indexOf("terminated") > 0 )
					{
						this.sendEvent(new TerminatedEvent());
						this.process.stdin.write(`quit\n\n`)
					}
				}
				catch(ex)
				{
					this.sendEvent(new OutputEvent(`${ex}\n`));
				}
			}

			// TODO: separate method
			var fullLine = `${this._fullDebugOutput.pop()}${list.shift()}`;
			this._fullDebugOutput.push(fullLine);
			this._fullDebugOutput = this._fullDebugOutput.concat(list);
		});

		this.process.stderr.on("data", (data)=>
		{
			this.sendEvent(new OutputEvent(`stderr: ${data}\n`));
		});

		this.process.on("exit", (() => { this.emit("quit"); }).bind(this));

		this._sourceFile = args.program;
		this._sourceLines = readFileSync(this._sourceFile).toString().split('\n');

		setTimeout(()=>this.launchRequestFinalize(response, args), 10);
	}

	private launchRequestFinalize(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		for (var i = 0; i < this._fullDebugOutput.length; i++) {
			if (this._fullDebugOutput[i].indexOf("(/") == 0)
			{
				this.sendResponse(response);
				this.sendEvent(new InitializedEvent());
				this.sendEvent(new StoppedEvent("entry", BashDebugSession.THREAD_ID));
				return;
			}
		}

		setTimeout(()=>this.launchRequestFinalize(response, args), 100);
	}


	protected setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): void {

		// TODO: implement properly
		this.sendEvent(new OutputEvent(`setBreakPointsRequest: ${args.breakpoints.join(",")}\n`));

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.setBreakPointsRequest(response, args), 100);
			return;
		}

		var breakpoints = new Array<Breakpoint>();

		if (args.breakpoints.length == 0){
			response.body = { breakpoints: breakpoints };
			this.sendResponse(response);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`break ${args.breakpoints[0].line}\nprint BASHDB\n`);
		setTimeout(()=>	this.setBreakPointsRequestFinalize(response, args, currentLine, 0, breakpoints), 100);
	}

	private setBreakPointsRequestFinalize(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments, currentOutputLength:number, currentBreakpoint:number, breakpoints:Array<Breakpoint>): void {
		this.sendResponse(response);

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == "BASHDB"){
			const bp = <DebugProtocol.Breakpoint> new Breakpoint(true, this.convertDebuggerLineToClient(args.breakpoints[currentBreakpoint].line));
			bp.id = this._breakpointId++;
			breakpoints.push(bp);

			if (currentBreakpoint + 1 == args.breakpoints.length){
				response.body = { breakpoints: breakpoints };
				this.sendEvent(new OutputEvent(`setBreakPointsRequestDone\n`));
				this._debuggerExecutableBusy = false;
				this.sendResponse(response);
				return;
			}

			var currentLine = this._fullDebugOutput.length;
			this.process.stdin.write(`break ${args.breakpoints[currentBreakpoint + 1].line}\nprint BASHDB\n`);
			setTimeout(()=> this.setBreakPointsRequestFinalize(response, args, currentLine, currentBreakpoint + 1, breakpoints), 0);
			return;
		}

		setTimeout(()=> this.setBreakPointsRequestFinalize(response, args, currentOutputLength, currentBreakpoint, breakpoints), 100);
	}

	protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {

		this.sendEvent(new OutputEvent(`threadsRequest: \n`));
		// return the default thread
		response.body = {
			threads: [
				new Thread(BashDebugSession.THREAD_ID, "thread 1")
			]
		};

		this.sendEvent(new OutputEvent(`threadRequestDone\n`));
		this.sendResponse(response);
	}

	/**
	 * Returns a fake 'stacktrace' where every 'stackframe' is a word from the current line.
	 */
	protected stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {

		this.sendEvent(new OutputEvent(`stackTraceRequest: ${args.startFrame}  ${args.levels}\n`));

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.stackTraceRequest(response, args), 100);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`backtrace\nprint BASHDB\n`);
		setTimeout(() => this.stackTraceRequestFinalize(response, args, currentLine), 100);
	}

	private stackTraceRequestFinalize(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments, currentOutputLength:number): void {
		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == "BASHDB"){

			var lastStackLineIndex = this._fullDebugOutput.length - 3;

			const startFrame = typeof args.startFrame === 'number' ? args.startFrame : 0;
			const maxLevels = typeof args.levels === 'number' ? args.levels : 100;

			const frames = new Array<StackFrame>();
			for (var i= currentOutputLength - 1; i <= lastStackLineIndex ; i++) {
				var lineContent = this._fullDebugOutput[i];
				var frameIndex = parseInt(lineContent.substr(2, 2));
				var frameText = lineContent.substr(2, 2);
				var frameSourcePath = lineContent.substr(lineContent.lastIndexOf("`") + 1, lineContent.lastIndexOf("'") - lineContent.lastIndexOf("`") - 1);
				var frameLine = parseInt(lineContent.substr(lineContent.lastIndexOf(" ")));

				//this.sendEvent(new OutputEvent(`BBBBBB ${lineContent}\n${frameSourcePath}\n`));

				frames.push(new StackFrame(
					frameIndex,
					frameText,
					new Source(basename(frameSourcePath), this.convertDebuggerPathToClient(frameSourcePath)),
					this.convertDebuggerLineToClient(frameLine)
					));
			}

			var totalFrames = this._fullDebugOutput.length - currentOutputLength -1;

			response.body = { stackFrames: frames, totalFrames: totalFrames };
			this.sendEvent(new OutputEvent(`stackTraceRequestDone\n`));
			this._debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		setTimeout(() => this.stackTraceRequestFinalize(response, args, currentOutputLength), 100);
	}

	protected scopesRequest(response: DebugProtocol.ScopesResponse, args: DebugProtocol.ScopesArguments): void {

		// TODO: implement properly
		this.sendEvent(new OutputEvent(`scopesRequest: \n`));

		const frameReference = args.frameId;
		const scopes = new Array<Scope>();
		scopes.push(new Scope("Local", this._variableHandles.create("local_" + frameReference), false));

		response.body = {
			scopes: scopes
		};
		this.sendResponse(response);
	}

	protected variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): void {

		this.sendEvent(new OutputEvent(`variablesRequest: ${args.variablesReference.toString()}\n`));

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.variablesRequest(response, args), 100);
			return;
		}

		const variables = [];

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`examine $0\nprint BASHDB\n`);
		setTimeout(()=> this.variablesRequestFinalize(response, args, currentLine, 0, variables), 10);
	}

	private variablesRequestFinalize(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments, currentOutputLength:number, currentVariable:number, variables:Array<DebugProtocol.Variable>): void {

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == "BASHDB"){
			variables.push({
				name: `$${currentVariable}`,
				type: "string",
				value: this._fullDebugOutput[currentOutputLength - 1],
				variablesReference: 0
			});

			if (currentVariable +1 > 10){
				response.body = { variables: variables };

				this._debuggerExecutableBusy = false;
				this.sendResponse(response);
				this.sendEvent(new OutputEvent(`variablesRequestDone\n`));
				return;
			}

			this.process.stdin.write(`examine $${currentVariable + 1}\nprint BASHDB\n`);
			setTimeout(()=> this.variablesRequestFinalize(response, args, this._fullDebugOutput.length, currentVariable + 1, variables), 0);
			return;
		}

		setTimeout(()=> this.variablesRequestFinalize(response, args, currentOutputLength, currentVariable, variables), 10);
	}

	protected continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {

		this.sendEvent(new OutputEvent(`continueRequest: ${args.threadId}\n`));
		this.process.stdin.write(`continue\nprint BASHDB\n`);
		this.sendResponse(response);
	}

	protected nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {

		this.sendEvent(new OutputEvent(`nextRequest: ${args.threadId}\n`));
		this.process.stdin.write(`step\nprint BASHDB\n`);
		this.sendResponse(response);
	}

	protected stepBackRequest(response: DebugProtocol.StepBackResponse, args: DebugProtocol.StepBackArguments): void {

		this.sendEvent(new OutputEvent(`stepBackRequest: ${args.threadId}\n`));
		this.process.stdin.write(`step-\nprint BASHDB\n`);
		this.sendResponse(response);
	}

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {

		this.sendEvent(new OutputEvent(`evaluateRequest: ${args.context}  ${args.expression}\n\n`));

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.evaluateRequest(response, args), 100);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`examine ${args.expression}\nprint BASHDB\n`);
		setTimeout(()=>this.evaluateRequestFinalize(response, args, currentLine), 10);
	}

	private evaluateRequestFinalize(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments, currentOutputLength:number): void {

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == "BASHDB")
		{
			this.sendEvent(new OutputEvent(`${args.expression}: ${this._fullDebugOutput[currentOutputLength - 1]}\n`));

			response.body = {
				result: `${args.expression} = '${this._fullDebugOutput[currentOutputLength - 1]}'`,
				variablesReference: 0
			};

			this._debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}


		setTimeout(()=>this.evaluateRequestFinalize(response, args, currentOutputLength), 10);
	}



	protected breakpoints: Map<Breakpoint, Number> = new Map<Breakpoint, Number>();
	protected buffer: string;
	protected errbuf: string;

	protected process: ChildProcess.ChildProcess;
}

DebugSession.run(BashDebugSession);
