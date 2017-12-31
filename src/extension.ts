'use strict';

import * as vscode from 'vscode';
import { WorkspaceFolder, DebugConfiguration, ProviderResult, CancellationToken } from 'vscode';

export function activate(context: vscode.ExtensionContext) {

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.getProgramName', config => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the relative path to bash script.",
			value: (process.platform === "win32") ? "{workspaceRoot}\\path\\to\\script.sh" : "{workspaceRoot}/path/to/script.sh"
		}).then((result)=>{
			if (!result) {
				return undefined; // canceled, abort launch
			};
			result = result.replace("{workspaceRoot}", <string>vscode.workspace.rootPath);
			return (process.platform === "win32") ? "/mnt/" + result.substr(0, 1).toLowerCase() + result.substr("X:".length).split("\\").join("/") : result;
		});
	}));

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.selectProgramName', config => {

		return vscode.workspace.findFiles("**/*.sh", "").then((uris) => {
			const list = new Array<string>();
			for (let i = 0; i < uris.length; i++) {
				list.push(uris[i].fsPath);
			}
			return vscode.window.showQuickPick(list).then((result)=>{
				if (!result) {
					return undefined; // canceled, abort launch
				}
				return (process.platform === "win32") ? "/mnt/" + result.substr(0, 1).toLowerCase() + result.substr("X:".length).split("\\").join("/") : result;
			});
		});
	}));

	// register a configuration provider for 'bash' debug type
	context.subscriptions.push(vscode.debug.registerDebugConfigurationProvider('mock', new BashConfigurationProvider()));
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
			if (editor && editor.document.languageId === 'shellscript' ) {
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