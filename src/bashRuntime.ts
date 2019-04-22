import { spawnBashScriptSync } from './spawnBash';

enum validatePathResult {
	success = 0,
	notExistCwd,
	notFoundBash,
	notFoundBashdb,
	notFoundCat,
	notFoundMkfifo,
	notFoundPkill,
	timeout,
	cannotChmod,
	unsupportedBashVersion,
	unknown,
}

/**
 * @example
 * _validatePath("./", "bash", "type", "type", "type", "type");
 * // => validatePathResult.success
 *
 * @example
 * _validatePath("non-exist-directory", "bash", "type", "type", "type", "type");
 * // => validatePathResult.notExistCwd
 *
 * @example
 * _validatePath("./", "invalid-bash-path", "type", "type", "type", "type");
 * // => validatePathResult.notFoundBash
 *
 * @example
 * _validatePath("./", "bash", "invalid-bashdb-path", "type", "type", "type");
 * // => validatePathResult.notFoundBashdb
 *
 * @example
 * _validatePath("./", "bash", "type", "invalid-cat-path", "type", "type");
 * // => validatePathResult.notFoundCat
 *
 * @example
 * _validatePath("./", "bash", "type", "type", "invalid-mkfifo-path", "type");
 * // => validatePathResult.notFoundMkfifo
 *
 * @example
 * _validatePath("./", "bash", "type", "type", "type", "invalid-pkill-path");
 * // => validatePathResult.notFoundPkill
 *
 * @example
 * _validatePath("./", "bash", "type", "type", "type", "invalid-pkill-path");
 * // => validatePathResult.notFoundPkill
 *
 * @example
 * _validatePath("invalid-path", "invalid-path", "invalid-path", "invalid-path", "invalid-path", "invalid-path");
 * // => validatePathResult.notFoundBash
 *
 * @example
 * _validatePath("./", "bash", "", "", "", "", 1);
 * // => validatePathResult.timeout
 */
function _validatePath(cwd: string,
	pathBash: string, pathBashdb: string, pathCat: string, pathMkfifo: string, pathPkill: string, spawnTimeout: number = 5000): [validatePathResult, string] {

	const vpr = validatePathResult;

	const proc = spawnBashScriptSync(
		((pathBashdb.indexOf("bashdb_dir") > 0) ? `chmod +x "${pathBashdb}" || exit ${vpr.cannotChmod};` : ``) +
		`type "${pathBashdb}" || exit ${vpr.notFoundBashdb};` +
		`type "${pathCat}" || exit ${vpr.notFoundCat};` +
		`type "${pathMkfifo}" || exit ${vpr.notFoundMkfifo};` +
		`type "${pathPkill}" || exit ${vpr.notFoundPkill};` +
		`test -d "${cwd}" || exit ${vpr.notExistCwd};` +
		`[[ "$BASH_VERSION" == 4.* ]] || [[ "$BASH_VERSION" == 5.* ]] || exit ${vpr.unsupportedBashVersion};`, pathBash, spawnTimeout);

	if (proc.error !== undefined) {
		// @ts-ignore Property 'code' does not exist on type 'Error'.
		if (proc.error.code === "ENOENT") {
			return [vpr.notFoundBash, ""];
		}
		// @ts-ignore Property 'code' does not exist on type 'Error'.
		if (proc.error.code === "ETIMEDOUT") {
			return [vpr.timeout, ""];
		}
		return [vpr.unknown, ""];
	}

	const errorString = proc.stderr.toString();

	return [<validatePathResult>proc.status, errorString];
}

/**
 * @returns "" on success, non-empty error message on failure.
 * @example
 * validatePath("./", "bash", "type", "type", "type", "type");
 * // => ""
 * @example
 * validatePath("non-exist-directory", "bash", "type", "type", "type", "type");
 * // => "Error: cwd (non-exist-directory) does not exist."
 */
export function validatePath(cwd: string,
	pathBash: string, pathBashdb: string, pathCat: string, pathMkfifo: string, pathPkill: string): string {

	const rc = _validatePath(cwd, pathBash, pathBashdb, pathCat, pathMkfifo, pathPkill);

	const askReport = `If it is reproducible, please report it to https://github.com/rogalmic/vscode-bash-debug/issues.`;

	const stderrContent = `\n\n${rc["1"]}`;

	switch (rc["0"]) {
		case validatePathResult.success: {
			return ``;
		}
		case validatePathResult.notExistCwd: {
			return `Error: cwd (${cwd}) does not exist.` + stderrContent;
		}
		case validatePathResult.notFoundBash: {
			if ( process.platform == "win32" )
			{
				return `Error: WSL bash (mandatory on Windows) is not found. (pathBash: ${pathBash})` + stderrContent;
			} else {
				return `Error: bash not found. (pathBash: ${pathBash})` + stderrContent;
			}
		}
		case validatePathResult.notFoundBashdb: {
			return `Error: bashdb not found. (pathBashdb: ${pathBashdb})` + stderrContent;
		}
		case validatePathResult.notFoundCat: {
			return `Error: cat not found. (pathCat: ${pathCat})` + stderrContent;
		}
		case validatePathResult.notFoundMkfifo: {
			return `Error: mkfifo not found. (pathMkfifo: ${pathMkfifo})` + stderrContent;
		}
		case validatePathResult.notFoundPkill: {
			return `Error: pkill not found. (pathPkill: ${pathPkill})` + stderrContent;
		}
		case validatePathResult.timeout: {
			return `Error: BUG: timeout while validating environment. ` + askReport  + stderrContent;
		}
		case validatePathResult.cannotChmod: {
			return `Error: Cannot chmod +x internal bashdb copy.` + stderrContent;
		}
		case validatePathResult.unsupportedBashVersion: {
			return `Error: Only bash versions 4.* are supported.` + stderrContent;
		}
		case validatePathResult.unknown: {
			return `Error: BUG: unknown error ocurred while validating environment. ` + askReport + stderrContent;
		}
	}

	return `Error: BUG: reached to unreachable code while validating environment (code ${rc}). ` + askReport + stderrContent;
}

