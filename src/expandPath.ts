/**
 * @example <caption>When escape pressed. Abort launch.</caption>
 * // can't execute jsdoctest
 * // expandPath(undefined, "C:\\Users\\wsh\proj0"); // => undefined
 *
 * @example <caption>Absolute path</caption>
 * expandPath("C:\\Users\\wsh\\proj0\\path\\to\\script.sh", "C:\\Users\\wsh\proj0");
 * // => "/mnt/c/Users/wsh/proj0/path/to/script.sh"
 *
 * @example <caption>Using {workspaceFolder}, on windows</caption>
 * expandPath("{workspaceFolder}\\path\\to\\script.sh", "C:\\Users\\wsh\\proj0");
 * // => "/mnt/c/Users/wsh/proj0/path/to/script.sh"
 *
 * @example <caption>If path starts with "/", no WSL path conversion</caption>
 * expandPath("/mnt/c/Users/wsh/proj0/path/to/script.sh", "C:\\Users\\wsh\\proj0");
 * // => "/mnt/c/Users/wsh/proj0/path/to/script.sh"
 */
export function expandPath(path?: string, rootPath?: string): string | undefined {

	if (!path) {
		return undefined;
	};

	if (rootPath) {
		path = path.replace("{workspaceFolder}", <string>rootPath);
	}

	if (!path.startsWith("/")) {
		path = "/mnt/" + path.substr(0, 1).toLowerCase() + path.substr("X:".length).split("\\").join("/");
	}

	return path;
}