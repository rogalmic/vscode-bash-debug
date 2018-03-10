import * as vscode from 'vscode';
import { WorkspaceFolder, DebugConfiguration, ProviderResult, CancellationToken } from 'vscode';

export function activate(context: vscode.ExtensionContext) {
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
		// If launch.json is missing or empty
		if (!config.type && !config.request && !config.name) {
			return undefined; // abort launch and create launch.json with "initialConfigurations"
		}

		// Else launch.json exists
		if (!config.type || !config.name) {
			let msg = "BUG in Bash Debug: reached to unreachable code.";
			msg += "\nPlease report this bug on: https://github.com/rogalmic/vscode-bash-debug/issues";
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
		if (!config.cwd) { config.cwd = "./" }
		if (!config.pathBash) { config.pathBash = "bash" }
		if (!config.pathBashdb) { config.pathBashdb = "bashdb" }
		if (!config.pathCat) { config.pathCat = "cat" }
		if (!config.pathMkfifo) { config.pathMkfifo = "mkfifo" }
		if (!config.pathPkill) { config.pathPkill = "pkill" }

		// These variables can be undefined, as indicated in `?` (optional type) in bashDebug.ts:LaunchRequestArguments
		// - config.showDebugOutput
		// - config.trace

		// Launch it
		return config;
	}
}
