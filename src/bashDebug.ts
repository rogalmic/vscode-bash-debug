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

class MockDebugSession extends DebugSession {

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
					this.sendEvent(new StoppedEvent("break", MockDebugSession.THREAD_ID));
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
				this.sendEvent(new StoppedEvent("entry", MockDebugSession.THREAD_ID));
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
			this.process.stdin.write(`break ${args.breakpoints[i].line}\n`)
		}


		var path = args.source.path;
		var clientLines = args.lines;

		// read file contents into array for direct access
		var lines = readFileSync(path).toString().split('\n');

		var breakpoints = new Array<Breakpoint>();

		// verify breakpoint locations
		for (var i = 0; i < clientLines.length; i++) {
			var l = this.convertClientLineToDebugger(clientLines[i]);
			var verified = false;
			if (l < lines.length) {
				const line = lines[l].trim();
				// if a line is empty or starts with '+' we don't allow to set a breakpoint but move the breakpoint down
				if (line.length == 0 || line.indexOf("+") == 0)
					l++;
				// if a line starts with '-' we don't allow to set a breakpoint but move the breakpoint up
				if (line.indexOf("-") == 0)
					l--;
				// don't set 'verified' to true if the line contains the word 'lazy'
				// in this case the breakpoint will be verified 'lazy' after hitting it once.
				if (line.indexOf("lazy") < 0) {
					verified = true;    // this breakpoint has been validated
				}
			}
			const bp = <DebugProtocol.Breakpoint> new Breakpoint(verified, this.convertDebuggerLineToClient(l));
			bp.id = this._breakpointId++;
			breakpoints.push(bp);
		}
		this._breakPoints.set(path, breakpoints);

		// send back the actual breakpoint positions
		response.body = {
			breakpoints: breakpoints
		};

		setTimeout(()=>this.setBreakPointsRequestFinalize(response, args, this._fullDebugOutput.length), 100);
	}

	private setBreakPointsRequestFinalize(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments, currenLength:number): void {
		this.sendResponse(response);
	}

	protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {

		this.sendEvent(new OutputEvent(`threadsRequest: \n`));
		// return the default thread
		response.body = {
			threads: [
				new Thread(MockDebugSession.THREAD_ID, "thread 1")
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
		scopes.push(new Scope("Closure", this._variableHandles.create("closure_" + frameReference), false));
		scopes.push(new Scope("Global", this._variableHandles.create("global_" + frameReference), true));

		response.body = {
			scopes: scopes
		};
		this.sendResponse(response);
	}

	protected variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): void {

		this.sendEvent(new OutputEvent(`variablesRequest: ${args.variablesReference.toString()}\n`));


		const variables = [];
		const id = this._variableHandles.get(args.variablesReference);
		if (id != null) {
			variables.push({
				name: id + "_i",
				type: "integer",
				value: "123",
				variablesReference: 0
			});
			variables.push({
				name: id + "_f",
				type: "float",
				value: "3.14",
				variablesReference: 0
			});
			variables.push({
				name: id + "_s",
				type: "string",
				value: "hello world",
				variablesReference: 0
			});
			variables.push({
				name: id + "_o",
				type: "object",
				value: "Object",
				variablesReference: this._variableHandles.create("object_")
			});
		}

		response.body = {
			variables: variables
		};
		this.sendResponse(response);
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

		var initialLength = this._fullDebugOutput.length;
		this.process.stdin.write(`examine ${args.expression}\n`);

		setTimeout(()=>this.evaluateRequestFinalize(response, args, this._fullDebugOutput.length), 100);
	}

	private evaluateRequestFinalize(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments, currenLength:number): void {

		if (this._fullDebugOutput.length > currenLength && this._fullDebugOutput[currenLength].length > 0)
		{
			this.sendEvent(new OutputEvent(`${args.expression}: ${this._fullDebugOutput[currenLength]}\n`));

			response.body = {
				result: `${args.expression} = '${this._fullDebugOutput[currenLength]}'`,
				variablesReference: 0
			};

			this.sendResponse(response);
			return;
		}


		setTimeout(()=>this.evaluateRequestFinalize(response, args, currenLength), 100);
	}



	protected breakpoints: Map<Breakpoint, Number> = new Map<Breakpoint, Number>();
	protected buffer: string;
	protected errbuf: string;

	protected process: ChildProcess.ChildProcess;
}

DebugSession.run(MockDebugSession);
