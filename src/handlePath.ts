import { join } from 'path';

/**
 * @example <caption>Undefined path stays undefined.</caption>
 * // can't execute jsdoctest
 * // expandPath(undefined, "C:\\Users\\wsh\proj0"); // => undefined
 *
 * @example <caption>Absolute path is not replaced.</caption>
 * expandPath("C:\\Users\\wsh\\proj0\\path\\to\\script.sh", "C:\\Users\\wsh\proj0");
 * // => "C:/Users/wsh/proj0/path/to/script.sh"
 *
 * @example <caption>Using {workspaceFolder}, on windows</caption>
 * expandPath("{workspaceFolder}\\path\\to\\script.sh", "C:\\Users\\wsh\\proj0");
 * // => "C:/Users/wsh/proj0/path/to/script.sh"
 */
export function expandPath(path?: string, rootPath?: string): string | undefined {

	if (!path) {
		return undefined;
	}

	if (rootPath) {
		path = path.replace("{workspaceFolder}", <string>rootPath).split("\\").join("/");
	}

	return path;
}

/**
 * @example <caption>Undefined path stays undefined.</caption>
 * // can't execute jsdoctest
 * // getWSLPath(undefined); // => undefined
 *
 * @example <caption>If windows path, WSL path conversion</caption>
 * getWSLPath("C:\\Users\\wsh\\proj0\\path\\to\\script.sh");
 * // => "/mnt/c/Users/wsh/proj0/path/to/script.sh"
 *
 * @example <caption>If path starts with "/", no WSL path conversion</caption>
 * getWSLPath("/mnt/c/Users/wsh/proj0/path/to/script.sh");
 * // => "/mnt/c/Users/wsh/proj0/path/to/script.sh"
 */
export function getWSLPath(path?: string): string | undefined {

	if (!path) {
		return undefined;
	}

	if (!path.startsWith("/")) {
		path = "/mnt/" + path.substr(0, 1).toLowerCase() + path.substr("X:".length).split("\\").join("/");
	}

	return path;
}

/**
 * @example <caption>Absolute path</caption>
 * reverseWSLPath("/mnt/c/Users/wsh/proj0/path/to/script.sh");
 * // => "C:\\Users\\wsh\\proj0\\path\\to\\script.sh"
 */
export function reverseWSLPath(wslPath: string): string {

	if (wslPath.startsWith("/mnt/")) {
		return wslPath.substr("/mnt/".length, 1).toUpperCase() + ":" + wslPath.substr("/mnt/".length + 1).split("/").join("\\");
	}

	return wslPath.split("/").join("\\");
}

export function getWSLLauncherPath(useInShell: boolean): string {

	if (useInShell) {
		return "wsl.exe";
	}

	return process.env.hasOwnProperty('PROCESSOR_ARCHITEW6432') ?
		join("C:", "Windows", "sysnative", "wsl.exe") :
		join("C:", "Windows", "System32", "wsl.exe");
}

/**
 * @example <caption>Escape whitespace for setting bashdb arguments with spaces</caption>
 * escapeCharactersInBashdbArg("/pa th/to/script.sh");
 * // => "/pa\\\\040th/to/script.sh"
 */
export function escapeCharactersInBashdbArg(path: string): string {
	return path.replace(/\s/g, (m) => "\\\\" + ("0000" + m.charCodeAt(0).toString(8)).slice(-4));
}

