import * as vscode from 'vscode';
import { expandPath } from './expandPath';

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
}

export function deactivate() {
	// nothing to do
}