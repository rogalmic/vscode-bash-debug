import * as vscode from 'vscode';
import { WorkspaceFolder, DebugConfiguration, ProviderResult, CancellationToken } from 'vscode';
import { expandPath, getWSLPath } from './handlePath';
import { normalize, join } from 'path';

export function activate(context: vscode.ExtensionContext) {

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.getProgramName', config => {
		// Invoked if any property in client's launch.json has ${command:AskForScriptName} (mapped to getProgramName
		// in package.json) in its value.
		return vscode.window.showInputBox({
			placeHolder: "Type absolute path to bash script.",
			value: (process.platform === "win32") ? "{workspaceFolder}\\path\\to\\script.sh" : "{workspaceFolder}/path/to/script.sh"
		}).then(v => expandPath(v, vscode.workspace.rootPath));
	}));

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.selectProgramName', config => {
		// Invoked if any property in client's launch.json has ${command:SelectScriptName} (mapped to selectProgramName
		// in package.json) in its value.
		return vscode.workspace.findFiles("**/*.sh", "").then((uris) => {
			const list = new Array<string>();
			for (let i = 0; i < uris.length; i++) {
				list.push(uris[i].fsPath);
			}
			return vscode.window.showQuickPick(list).then((result) => {
				if (!result) {
					return undefined; // canceled, abort launch
				}
				return result;
			}).then(v => expandPath(v, vscode.workspace.rootPath));
		});
	}));

	context.subscriptions.push(vscode.debug.registerDebugConfigurationProvider('bashdb', new BashConfigurationProvider()));
}

export function deactivate() {
	// nothing to do
}

class BashConfigurationProvider implements vscode.DebugConfigurationProvider {
	/**
	 * Check configuration just before a debug session is being launched.
	 */
	resolveDebugConfiguration(folder: WorkspaceFolder | undefined, config: DebugConfiguration, token?: CancellationToken): ProviderResult<DebugConfiguration> {
		if (!config.type && !config.request && !config.name) {
			// If launch.json is missing or empty, abort launch and create launch.json with "initialConfigurations"
			return undefined;
		}

		if (!folder) {
			let msg = "Unable to determine workspace folder.";
			return vscode.window.showErrorMessage(msg).then(_ => { return undefined; });
		}

		// Else launch.json exists
		if (!config.type || !config.name) {
			let msg = "BUG in Bash Debug: reached to unreachable code.";
			msg += "\nIf it is reproducible, please report this bug on: https://github.com/rogalmic/vscode-bash-debug/issues";
			msg += "\nYou can avoid this bug by setting \"type\" and \"name\" attributes in launch.json.";
			return vscode.window.showErrorMessage(msg).then(_ => { return undefined; });
		}
		if (!config.request) {
			let msg = "Please set \"request\" attribute to \"launch\".";
			return vscode.window.showErrorMessage(msg).then(_ => { return undefined; });
		}

		// Abort launch if any deprecated argument is included
		if (config.bashDbPath) {
			return vscode.window.showErrorMessage("`bashDbPath` is deprecated. Use `pathBashdb` instead.").then(_ => { return undefined; });
		}
		if (config.bashPath) {
			return vscode.window.showErrorMessage("`bashPath` is deprecated. Use `pathBash` instead.").then(_ => { return undefined; });
		}
		if (config.commandLineArguments) {
			return vscode.window.showErrorMessage("`commandLineArguments` is deprecated. Use `args` instead.").then(_ => { return undefined; });
		}
		if (config.scriptPath) {
			return vscode.window.showErrorMessage("`scriptPath` is deprecated. Use `program` instead.").then(_ => { return undefined; });
		}

		// Check "required" attributes (defined in package.json) are included
		if (!config.program) {
			return vscode.window.showErrorMessage("Please specify \"program\" in launch.json.").then(_ => { return undefined; });
		}

		// Fill non-"required" attributes with default values to prevent bashdb (or other programs) from panic
		if (!config.args) { config.args = [] }
		if (!config.cwd) { config.cwd = folder.uri.fsPath }
		if (!config.pathBash) {
			if (process.platform === "win32") {
				config.pathBash = process.env.hasOwnProperty('PROCESSOR_ARCHITEW6432') ?
					"C:\\Windows\\sysnative\\bash.exe" : "C:\\Windows\\System32\\bash.exe";
			}
			else {
				config.pathBash = "bash"
			}
		}
		if (!config.pathBashdb) {
			if (process.platform === "win32") {
				config.pathBashdb = getWSLPath(normalize(join(__dirname, "..\\bashdb")));
			}
			else {
				config.pathBashdb = normalize(join(__dirname, "..\\bashdb"));
			}
		}
		if (!config.pathBashdbLib) {
			if (process.platform === "win32") {
				config.pathBashdbLib = getWSLPath(normalize(join(__dirname, "..\\bashdb_dir")));
			}
			else {
				config.pathBashdbLib = normalize(join(__dirname, "..\\bashdb_dir"));
			}
		}
		if (!config.pathCat) { config.pathCat = "cat" }
		if (!config.pathMkfifo) { config.pathMkfifo = "mkfifo" }
		if (!config.pathPkill) { config.pathPkill = "pkill" }

		// These variables can be undefined, as indicated in `?` (optional type) in bashDebug.ts:LaunchRequestArguments
		// - config.showDebugOutput
		// - config.trace

		return config;
	}
}
