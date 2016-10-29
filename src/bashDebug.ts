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

	private static THREAD_ID = 42;
	private static BASHDB_PROMPT = "=BASHDB=";

	private __currentLine = 0;
	private get _currentLine() : number {
		return this.__currentLine;
    }
	private set _currentLine(line: number) {
		this.__currentLine = line;
		this.sendEvent(new OutputEvent(`line: ${line}\n`));
	}

	protected process: ChildProcess.ChildProcess;

	private _variableHandles = new Handles<string>();

	private _fullDebugOutput = [""];

	private _debuggerExecutableBusy = false;

	private _responsivityFactor = 20;

	public constructor() {
		super();
		this.setDebuggerLinesStartAt1(true);
		this.setDebuggerColumnsStartAt1(true);
	}

	protected initializeRequest(response: DebugProtocol.InitializeResponse, args: DebugProtocol.InitializeRequestArguments): void {

		response.body.supportsConfigurationDoneRequest = false; //TODO: implement configDone if needed
		response.body.supportsEvaluateForHovers = true;
		response.body.supportsStepBack = false;

		this.sendResponse(response);
	}

	protected launchRequest(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		this.configurationDoneRequest
		this.process = ChildProcess.spawn("bashdb", ["--quiet", args.program]);

		this.process.stdout.on("data", (data) =>
		{
			this.sendEvent(new OutputEvent(`${data}`));

			var list = data.toString().split("\n", -1);

			for (var i=list.length-1; i>=0; i--)
			{
				try
				{
					if (list[i].indexOf("(/") == 0)
					{
						var res = list[i].replace("(", "").replace(")", "");
						this.sendEvent(new OutputEvent(`line: ${res}\n`));
						this._currentLine = parseInt(res.split(":", -1)[1]);
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

			// TODO: separate method to smaller pieces
			var fullLine = `${this._fullDebugOutput.pop()}${list.shift()}`;
			this._fullDebugOutput.push(fullLine);
			this._fullDebugOutput = this._fullDebugOutput.concat(list);
		});

		this.process.stderr.on("data", (data)=>
		{
			this.sendEvent(new OutputEvent(`stderr: ${data}\n`));
		});

		this.process.on("exit", (() => { this.emit("quit"); }).bind(this));

		setTimeout(()=>this.launchRequestFinalize(response, args), this._responsivityFactor);
	}

	private launchRequestFinalize(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		for (var i = 0; i < this._fullDebugOutput.length; i++) {
			if (this._fullDebugOutput[i].indexOf("(/") == 0)
			{
				this.sendResponse(response);
				this.sendEvent(new InitializedEvent());
				// TODO: is stop needed here? --> check configuration done request
				this.sendEvent(new StoppedEvent("entry", BashDebugSession.THREAD_ID));
				return;
			}
		}

		setTimeout(()=>this.launchRequestFinalize(response, args), this._responsivityFactor);
	}


	protected setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): void {

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.setBreakPointsRequest(response, args), this._responsivityFactor);
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
		this.process.stdin.write(`break ${args.breakpoints[0].line}\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);
		setTimeout(()=>	this.setBreakPointsRequestFinalize(response, args, currentLine, 0, breakpoints), this._responsivityFactor);
	}

	private setBreakPointsRequestFinalize(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments, currentOutputLength:number, currentBreakpoint:number, breakpoints:Array<Breakpoint>): void {
		this.sendResponse(response);

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length - 2] == BashDebugSession.BASHDB_PROMPT){
			const bp = <DebugProtocol.Breakpoint> new Breakpoint(true, this.convertDebuggerLineToClient(args.breakpoints[currentBreakpoint].line));
			bp.id = parseInt(this._fullDebugOutput[this._fullDebugOutput.length -3].split(" ")[1]);
			breakpoints.push(bp);

			if (currentBreakpoint + 1 == args.breakpoints.length){
				response.body = { breakpoints: breakpoints };
				this._debuggerExecutableBusy = false;
				this.sendResponse(response);
				return;
			}

			var currentLine = this._fullDebugOutput.length;
			this.process.stdin.write(`break ${args.breakpoints[currentBreakpoint + 1].line}\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);
			setTimeout(()=> this.setBreakPointsRequestFinalize(response, args, currentLine, currentBreakpoint + 1, breakpoints), 0);
			return;
		}

		setTimeout(()=> this.setBreakPointsRequestFinalize(response, args, currentOutputLength, currentBreakpoint, breakpoints), this._responsivityFactor);
	}

	protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {

		response.body = {
			threads: [
				new Thread(BashDebugSession.THREAD_ID, "Bash-Super-Thread")
			]
		};

		this.sendResponse(response);
	}

	protected stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.stackTraceRequest(response, args), this._responsivityFactor);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`backtrace\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);
		setTimeout(() => this.stackTraceRequestFinalize(response, args, currentLine), this._responsivityFactor);
	}

	private stackTraceRequestFinalize(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments, currentOutputLength:number): void {
		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == BashDebugSession.BASHDB_PROMPT){

			var lastStackLineIndex = this._fullDebugOutput.length - 3;

			const startFrame = typeof args.startFrame === 'number' ? args.startFrame : 0;
			const maxLevels = typeof args.levels === 'number' ? args.levels : 100;

			const frames = new Array<StackFrame>();
			for (var i= currentOutputLength - 1; i <= lastStackLineIndex ; i++) {
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

			response.body = { stackFrames: frames, totalFrames: totalFrames };
			this._debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		setTimeout(() => this.stackTraceRequestFinalize(response, args, currentOutputLength), this._responsivityFactor);
	}

	protected scopesRequest(response: DebugProtocol.ScopesResponse, args: DebugProtocol.ScopesArguments): void {

		const frameReference = args.frameId;
		const scopes = new Array<Scope>();
		scopes.push(new Scope("Local", this._variableHandles.create("local_" + frameReference), false));
		response.body = { scopes: scopes };
		this.sendResponse(response);
	}

	protected variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): void {

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.variablesRequest(response, args), this._responsivityFactor);
			return;
		}

		var variables = [];

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`examine $0\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);
		setTimeout(()=> this.variablesRequestFinalize(response, args, currentLine, 0, variables), this._responsivityFactor);
	}

	private variablesRequestFinalize(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments, currentOutputLength:number, currentVariable:number, variables:Array<DebugProtocol.Variable>): void {

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == BashDebugSession.BASHDB_PROMPT){
			variables.push({
				name: `$${currentVariable}`,
				type: "string",
				value: this._fullDebugOutput[currentOutputLength - 1],
				variablesReference: 0
			});

			if (currentVariable +1 > 9){
				response.body = { variables: variables };

				this._debuggerExecutableBusy = false;
				this.sendResponse(response);
				return;
			}

			this.process.stdin.write(`examine $${currentVariable + 1}\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);
			setTimeout(()=> this.variablesRequestFinalize(response, args, this._fullDebugOutput.length, currentVariable + 1, variables), 0);
			return;
		}

		setTimeout(()=> this.variablesRequestFinalize(response, args, currentOutputLength, currentVariable, variables), this._responsivityFactor);
	}

	protected continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.continueRequest(response, args), this._responsivityFactor);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`continue\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);

		setTimeout(()=>this.continueRequestFinalize(response, args, currentLine), this._responsivityFactor);
	}

	private continueRequestFinalize(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments, currentOutputLength:number): void {

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == BashDebugSession.BASHDB_PROMPT)
		{
			this._debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		setTimeout(()=>this.continueRequestFinalize(response, args, currentOutputLength), this._responsivityFactor);
	}

	protected nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.nextRequest(response, args), this._responsivityFactor);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`next\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);

		setTimeout(()=>this.nextRequestFinalize(response, args, currentLine), this._responsivityFactor);

		// TODO: why does it need to be here?
		this.sendResponse(response);
	}

	private nextRequestFinalize(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments, currentOutputLength:number): void {

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == BashDebugSession.BASHDB_PROMPT)
		{
			this._debuggerExecutableBusy = false;
			//this.sendResponse(response);
			return;
		}

		setTimeout(()=>this.nextRequestFinalize(response, args, currentOutputLength), this._responsivityFactor);
	}

	protected stepInRequest(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments): void {

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.stepInRequest(response, args), this._responsivityFactor);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`step\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);

		setTimeout(()=>this.stepInRequestFinalize(response, args, currentLine), this._responsivityFactor);

		// TODO: why does it need to be here?
		this.sendResponse(response);
	}

	private stepInRequestFinalize(response: DebugProtocol.StepInResponse, args: DebugProtocol.StepInArguments, currentOutputLength:number): void {
		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == BashDebugSession.BASHDB_PROMPT)
		{
			this._debuggerExecutableBusy = false;
			//this.sendResponse(response);
			return;
		}

		setTimeout(()=>this.stepInRequestFinalize(response, args, currentOutputLength), this._responsivityFactor);
	}

	protected stepBackRequest(response: DebugProtocol.StepBackResponse, args: DebugProtocol.StepBackArguments): void {

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.stepBackRequest(response, args), this._responsivityFactor);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`step -\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);

		setTimeout(()=>this.stepBackRequestFinalize(response, args, currentLine), this._responsivityFactor);

		// TODO: why does it need to be here?
		this.sendResponse(response);
	}

	private stepBackRequestFinalize(response: DebugProtocol.StepBackResponse, args: DebugProtocol.StepBackArguments, currentOutputLength:number): void {
		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == BashDebugSession.BASHDB_PROMPT)
		{
			this._debuggerExecutableBusy = false;
			//this.sendResponse(response);
			return;
		}

		setTimeout(()=>this.stepBackRequestFinalize(response, args, currentOutputLength), this._responsivityFactor);
	}

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {

		if (this._debuggerExecutableBusy)
		{
			setTimeout(()=>	this.evaluateRequest(response, args), this._responsivityFactor);
			return;
		}

		this._debuggerExecutableBusy = true;
		var currentLine = this._fullDebugOutput.length;
		this.process.stdin.write(`examine ${args.expression}\nprint ${BashDebugSession.BASHDB_PROMPT}\n`);
		setTimeout(()=>this.evaluateRequestFinalize(response, args, currentLine), this._responsivityFactor);
	}

	private evaluateRequestFinalize(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments, currentOutputLength:number): void {

		if (this._fullDebugOutput.length > currentOutputLength && this._fullDebugOutput[this._fullDebugOutput.length -2] == BashDebugSession.BASHDB_PROMPT)
		{
			response.body = { result: `${args.expression} = '${this._fullDebugOutput[currentOutputLength - 1]}'`, variablesReference: 0	};

			this._debuggerExecutableBusy = false;
			this.sendResponse(response);
			return;
		}

		setTimeout(()=>this.evaluateRequestFinalize(response, args, currentOutputLength), this._responsivityFactor);
	}
}

DebugSession.run(BashDebugSession);
