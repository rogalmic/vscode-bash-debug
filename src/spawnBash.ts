import { ChildProcess, SpawnSyncReturns, spawnSync, spawn } from 'child_process';
import { getWindowsLauncherPath } from './handlePath';

export function spawnBashScript(scriptCode: string, pathBash: string, useWsl: boolean, outputHandler?: (output: string, category?: string ) => void): ChildProcess{
	const currentShell  = (process.platform === "win32") ? getWindowsLauncherPath(false,useWsl) : pathBash;

	const optionalBashPathArgument = (currentShell !== pathBash && useWsl !==false) ? pathBash : "";

	let spawnedProcess = spawn(currentShell, [optionalBashPathArgument, "-c", scriptCode].filter(arg => arg !== ""), { stdio: ["pipe", "pipe", "pipe"], shell: false});

	if (outputHandler) {
		spawnedProcess.on("error", (error) => {
			outputHandler(`${error}`, `console`);
		});

		spawnedProcess.stderr.on("data", (data) => {
			outputHandler(`${data}`, `stderr`);
		});

		spawnedProcess.stdout.on("data", (data) => {
			outputHandler(`${data}`, `stdout`);
		});
	}

	return spawnedProcess;
}

export function spawnBashScriptSync(scriptCode: string, pathBash: string, spawnTimeout: number, useWsl: boolean): SpawnSyncReturns<Buffer>{
	const currentShell  = (process.platform === "win32") ? getWindowsLauncherPath(false, useWsl) : pathBash;
	const optionalBashPathArgument = (currentShell !== pathBash && useWsl !==false) ? pathBash : "";

	return spawnSync(currentShell, [optionalBashPathArgument, "-c", scriptCode].filter(arg => arg !== ""), { timeout: spawnTimeout, shell: false });
}