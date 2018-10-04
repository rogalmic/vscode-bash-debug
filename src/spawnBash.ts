import { ChildProcess, SpawnSyncReturns, spawnSync, spawn } from 'child_process';
import { getWSLLauncherPath } from './handlePath';

export function spawnBashScript(scriptCode: string, pathBash: string, outputHandler?: (output: string, category?: string ) => void): ChildProcess{
	const currentShell  = (process.platform === "win32") ? getWSLLauncherPath(false) : pathBash;
	const optionalBashPathArgument = (currentShell !== pathBash) ? pathBash : "";

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

export function spawnBashScriptSync(scriptCode: string, pathBash: string, spawnTimeout: number): SpawnSyncReturns<Buffer>{
	const currentShell  = (process.platform === "win32") ? getWSLLauncherPath(false) : pathBash;
	const optionalBashPathArgument = (currentShell !== pathBash) ? pathBash : "";

	return spawnSync(currentShell, [optionalBashPathArgument, "-c", scriptCode].filter(arg => arg !== ""), { timeout: spawnTimeout, shell: false });
}