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

	private _fullDebugOutput = new Array<string>();


	/**
	 * Creates a new debug adapter that is used for one debug session.
	 * We configure the default implementation of a debug adapter here.
	 */
	public constructor() {
		super();

		// this debugger uses zero-based lines and columns
		this.setDebuggerLinesStartAt1(false);
		this.setDebuggerColumnsStartAt1(false);
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

		this.process = ChildProcess.spawn("bashdb", [args.program]);

		this.process.stdout.on("data", (data) =>
		{
			this.sendEvent(new OutputEvent(`stdout: ${data}\n`));

			var list = data.toString().split("\n");

			this._fullDebugOutput = this._fullDebugOutput.concat(list);

			for (var i=list.length-1; i>=0; i--)
			{
				if (list[i].indexOf("(") == 0)
				{
					var res = list[i].replace("(", "").replace(")", "");
					this.sendEvent(new OutputEvent(`line: ${res}\n`));
					this._currentLine = parseInt(res.split(":")[1]) - 1;
					this._sourceFile = res.split(":")[0];
					this.sendEvent(new StoppedEvent("break", BashDebugSession.THREAD_ID));
				}
				else if (list[i].indexOf("terminated") > 0 )
				{
					this.sendEvent(new TerminatedEvent());
					this.process.stdin.write(`quit\n`)
				}
			}
		});

		this.process.stderr.on("data", (data)=>
		{
			this.sendEvent(new OutputEvent(`stderr: ${data}\n`));
		});

		this.process.on("exit", (() => { this.emit("quit"); }).bind(this));

		this._sourceFile = args.program;
		this._sourceLines = readFileSync(this._sourceFile).toString().split('\n');

		setTimeout(()=>this.launchRequestFinalize(response, args), 100);
	}

	private launchRequestFinalize(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		for (var i = 0; i < this._fullDebugOutput.length; i++) {
			if (this._fullDebugOutput[i].indexOf("(") == 0)
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

		for (var i = 0; i < args.breakpoints.length; i++)
		{
			this.sendEvent(new OutputEvent(`breakpoints: ${args.breakpoints[i].line} ${args.breakpoints[i].condition}\n`));
			//this.process.stdin.write(`break ${args.breakpoints[i].line}\n`)
		}

		var breakpoints = new Array<Breakpoint>();

		if (args.breakpoints.length == 0){
			response.body = { breakpoints: breakpoints };
			this.sendResponse(response);
			return;
		}

		this.process.stdin.write(`break ${args.breakpoints[0].line}\n`)
		setTimeout(()=>	this.setBreakPointsRequestFinalize(response, args, this._fullDebugOutput.length, 0, breakpoints), 100);
	}

	private setBreakPointsRequestFinalize(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments, currentOutputLength:number, currentBreakpoint:number, breakpoints:Array<Breakpoint>): void {
		this.sendResponse(response);

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[currentOutputLength].length > 0){
			const bp = <DebugProtocol.Breakpoint> new Breakpoint(true, this.convertDebuggerLineToClient(args.breakpoints[currentBreakpoint].line));
			bp.id = this._breakpointId++;
			breakpoints.push(bp);

			if (currentBreakpoint + 1 == args.breakpoints.length){
				response.body = { breakpoints: breakpoints };
				this.sendResponse(response);
				return;
			}
			// TODO: source file selection?
			this.process.stdin.write(`break ${args.breakpoints[currentBreakpoint + 1].line}\n`)
			setTimeout(()=> this.setBreakPointsRequestFinalize(response, args, this._fullDebugOutput.length, currentBreakpoint + 1, breakpoints), 0);
			return;
		}

		setTimeout(()=> this.setBreakPointsRequestFinalize(response, args, currentOutputLength, currentBreakpoint, breakpoints), 10);
	}

	protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {

		this.sendEvent(new OutputEvent(`threadsRequest: \n`));
		// return the default thread
		response.body = {
			threads: [
				new Thread(BashDebugSession.THREAD_ID, "thread 1")
			]
		};
		this.sendResponse(response);
	}

	/**
	 * Returns a fake 'stacktrace' where every 'stackframe' is a word from the current line.
	 */
	protected stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {

		// TODO: implement properly
		this.sendEvent(new OutputEvent(`stackTraceRequest: ${args.startFrame}  ${args.levels}\n`));

		//this.process.stdin.write(`backtrace\n`);

		setTimeout(this.stackTraceRequestFinalize(response, args), 100);
	}

	private stackTraceRequestFinalize(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {

		var initialLength = this._fullDebugOutput.length;
		const words = this._sourceLines[this._currentLine].trim().split(/\s+/);

		const startFrame = typeof args.startFrame === 'number' ? args.startFrame : 0;
		const maxLevels = typeof args.levels === 'number' ? args.levels : words.length-startFrame;
		const endFrame = Math.min(startFrame + maxLevels, words.length);

		const frames = new Array<StackFrame>();
		// every word of the current line becomes a stack frame.
		for (let i= startFrame; i < endFrame; i++) {
			const name = words[i];	// use a word of the line as the stackframe name
			frames.push(new StackFrame(i, `${name}(${i})`, new Source(basename(this._sourceFile),
				this.convertDebuggerPathToClient(this._sourceFile)),
				this.convertDebuggerLineToClient(this._currentLine), 0));
		}
		response.body = {
			stackFrames: frames,
			totalFrames: words.length
		};
		this.sendResponse(response);
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


		const variables = [];

		this.process.stdin.write(`examine $0\n`);
		setTimeout(()=> this.variablesRequestFinalize(response, args, this._fullDebugOutput.length, 0, variables), 0);
	}

	private variablesRequestFinalize(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments, currentOutputLength:number, currentVariable:number, variables:Array<DebugProtocol.Variable>): void {

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[currentOutputLength].length > 0){
			variables.push({
				name: `$${currentVariable}`,
				type: "string",
				value: this._fullDebugOutput[currentOutputLength],
				variablesReference: 0
			});

			if (currentVariable +1 > 10){
				response.body = { variables: variables };
				this.sendResponse(response);
				return;
			}

			this.process.stdin.write(`examine $${currentVariable + 1}\n`);
			setTimeout(()=> this.variablesRequestFinalize(response, args, this._fullDebugOutput.length, currentVariable + 1, variables), 0);
			return;
		}

		setTimeout(()=> this.variablesRequestFinalize(response, args, currentOutputLength, currentVariable, variables), 10);
	}

	protected continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {

		this.sendEvent(new OutputEvent(`continueRequest: ${args.threadId}\n`));
		this.process.stdin.write(`continue\n`);
		this.sendResponse(response);
	}

	protected nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {

		this.sendEvent(new OutputEvent(`nextRequest: ${args.threadId}\n`));
		this.process.stdin.write(`step\n`);
		this.sendResponse(response);
	}

	protected stepBackRequest(response: DebugProtocol.StepBackResponse, args: DebugProtocol.StepBackArguments): void {

		this.sendEvent(new OutputEvent(`stepBackRequest: ${args.threadId}\n`));
		this.process.stdin.write(`step-\n`);
		this.sendResponse(response);
	}

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {

		this.sendEvent(new OutputEvent(`evaluateRequest: ${args.context}  ${args.expression}\n`));

		this.process.stdin.write(`examine ${args.expression}\n`);

		setTimeout(()=>this.evaluateRequestFinalize(response, args, this._fullDebugOutput.length), 100);
	}

	private evaluateRequestFinalize(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments, currentOutputLength:number): void {

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[currentOutputLength].length > 0)
		{
			this.sendEvent(new OutputEvent(`${args.expression}: ${this._fullDebugOutput[currentOutputLength]}\n`));

			response.body = {
				result: `${args.expression} = '${this._fullDebugOutput[currentOutputLength]}'`,
				variablesReference: 0
			};

			this.sendResponse(response);
			return;
		}


		setTimeout(()=>this.evaluateRequestFinalize(response, args, currentOutputLength), 100);
	}



	protected breakpoints: Map<Breakpoint, Number> = new Map<Breakpoint, Number>();
	protected buffer: string;
	protected errbuf: string;

	protected process: ChildProcess.ChildProcess;
}

DebugSession.run(BashDebugSession);
