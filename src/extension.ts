'use strict';

import * as vscode from 'vscode';
import { WorkspaceFolder, DebugConfiguration, ProviderResult, CancellationToken } from 'vscode';
import { convertWindowsPath } from './extension_utils';

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
function expandPath(path?: string): string | undefined {
	if (!path) { return undefined; };

	path = path.replace("{workspaceFolder}", <string>vscode.workspace.rootPath);
	if (process.platform === "win32") {
		path = "/mnt/" + path.substr(0, 1).toLowerCase() + path.substr("X:".length).split("\\").join("/");
	}

	return path;
}

export function activate(context: vscode.ExtensionContext) {

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.getProgramName', config => {
		// Invoked if any property in client's launch.json has ${command:AskForScriptName} (mapped to getProgramName
		// in package.json) in its value.
		return vscode.window.showInputBox({
			placeHolder: "Type absolute path to bash script.",
			value: (process.platform === "win32") ? "{workspaceFolder}\\path\\to\\script.sh" : "{workspaceFolder}/path/to/script.sh"
		}).then(expandPath);
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
				return (process.platform === "win32") ? "/mnt/" + result.substr(0, 1).toLowerCase() + result.substr("X:".length).split("\\").join("/") : result;
			});
		});
	}));

	// register a configuration provider for 'bashdb' debug type
	context.subscriptions.push(vscode.debug.registerDebugConfigurationProvider('bashdb', new BashConfigurationProvider()));
}

export function deactivate() {
	// nothing to do
}

class BashConfigurationProvider implements vscode.DebugConfigurationProvider {

	/**
	 * Massage a debug configuration just before a debug session is being launched,
	 * e.g. add all missing attributes to the debug configuration.
	 */
	resolveDebugConfiguration(folder: WorkspaceFolder | undefined, config: DebugConfiguration, token?: CancellationToken): ProviderResult<DebugConfiguration> {

		// if launch.json is missing or empty
		if (!config.type && !config.request && !config.name) {
			const editor = vscode.window.activeTextEditor;
			if (editor && editor.document.languageId === 'shellscript') {
				config.type = 'bashdb';
				config.name = 'Launch';
				config.request = 'launch';
				config.program = '${file}';
				config.stopOnEntry = true;
				// TODO etc
			}
		}

		if (!config.program) {
			return vscode.window.showInformationMessage("Cannot find a program to debug").then(_ => {
				return undefined;	// abort launch
			});
		}

		return config;
	}
}