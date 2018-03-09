/**
 * @example <caption>When escape pressed. Abort launch.</caption>
 * expandPath(undefined); // => undefined

 * @example <caption>Absolute path, on linux and darwin</caption>
 * expandPath("/home/wsh/proj0/path/to/script.sh");
 * // => "/home/wsh/proj0/path/to/script.sh"
 * @example <caption>Using {workspaceFolder}, on linux and darwin</caption>
 * expandPath("{workspaceFolder}/path/to/script.sh");
 * // => "/home/wsh/proj0/path/to/script.sh"

 * @example <caption>Absolute path, on windows</caption>
 * expandPath("C:\\Users\\wsh\\proj0\\path\\to\\script.sh");
 * // => "/mnt/c/Users/wsh/proj0/path/to/script.sh"
 * @example <caption>Using {workspaceFolder}, on windows</caption>
 * expandPath("{workspaceFolder}\\path\\to\\script.sh");
 * // => "/mnt/c/Users/wsh/proj0/path/to/script.sh"
 */
export function expandPath(path?: string, rootPath?: string): string | undefined {

	if (!path) {
		return undefined;
	};

	if (rootPath) {
		path = path.replace("{workspaceFolder}", <string>rootPath);
	}

	if (process.platform === "win32" && !path.startsWith("/")) {
		path = "/mnt/" + path.substr(0, 1).toLowerCase() + path.substr("X:".length).split("\\").join("/");
	}

	return path;
}