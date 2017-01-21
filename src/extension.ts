'use strict';

import * as vscode from 'vscode';

const initialConfigurations = {
	configuration1: {
		"version": "0.2.0",
		"configurations": [
			{
				name: 'Bash-Debug (select script from list of sh files)',
				type: 'bashdb',
				request: 'launch',
				scriptPath: '${command.SelectScriptName}',
				commandLineArguments: '',
				windows: {
					bashPath: "C:\\Windows\\sysnative\\bash.exe"
				},
				linux: {
					bashPath: "bash"
				},
				osx: {
					bashPath: "bash"
				}
			}]
	},
	configuration2: {
		"version": "0.2.0",
		"configurations": [
			{
				name: 'Bash-Debug (hardcoded script name)',
				type: 'bashdb',
				request: 'launch',
				scriptPath: '${workspaceRoot}/path/to/script.sh',
				commandLineArguments: '',
				windows: {
					bashPath: "C:\\Windows\\sysnative\\bash.exe"
				},
				linux: {
					bashPath: "bash"
				},
				osx: {
					bashPath: "bash"
				}
			}]
	},
	configuration3: {
		"version": "0.2.0",
		"configurations": [
			{
				name: 'Bash-Debug (type in script name)',
				type: 'bashdb',
				request: 'launch',
				scriptPath: '${workspaceRoot}/${command.AskForScriptName}',
				commandLineArguments: '',
				windows: {
					bashPath: "C:\\Windows\\sysnative\\bash.exe"
				},
				linux: {
					bashPath: "bash"
				},
				osx: {
					bashPath: "bash"
				}
			}
		]
	}
}

export function activate(context: vscode.ExtensionContext) {

	context.subscriptions.push(vscode.commands.registerCommand('extension.getProgramName', () => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the relative path to bash script.",
			value: "./path/to/script.sh"
		});
	}));

	context.subscriptions.push(vscode.commands.registerCommand('extension.selectProgramName', () => {

		return vscode.workspace.findFiles("**/*.sh", "").then((uris) => {
			var list = new Array<string>();
			for (var i = 0 ; i < uris.length ; i++){
				var path = (process.platform == "win32") ? "/mnt/" + uris[i].fsPath.substr(0, 1).toLowerCase() + uris[i].fsPath.substr("X:".length).split("\\").join("/") : uris[i].fsPath;
				list.push(path);
			}
			return vscode.window.showQuickPick(list);
		});
	}));

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.provideInitialConfigurations', () => {

		return vscode.window.showQuickPick(
			["1. Script path should be selected from drop-down list of shell scripts in workspace",
			"2. Script path should be hardcoded in launch task",
			"3. Script path should be typed in by developer when launching"
		]).then((result)=>{
			switch(parseInt(result.substr(0,1)))
			{
				case 1:
					return JSON.stringify(initialConfigurations.configuration1, null, "\t");
				case 2:
					return JSON.stringify(initialConfigurations.configuration2, null, "\t");
				default:
					return JSON.stringify(initialConfigurations.configuration3, null, "\t");
			}
		})
	}));
}

export function deactivate() {
}
