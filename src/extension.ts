'use strict';

import * as vscode from 'vscode';

const initialConfigurations = {
	configuration1: {
		"version": "0.2.0",
		"configurations": [
			{
				type: 'bashdb',
				request: 'launch',
				name: 'Bash-Debug (select script from list of sh files)',
				executionDirectory: '${workspaceRoot}',
				scriptPath: '${command:SelectScriptName}',
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
				type: 'bashdb',
				request: 'launch',
				name: 'Bash-Debug (hardcoded script name)',
				executionDirectory: '${workspaceRoot}',
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
				type: 'bashdb',
				request: 'launch',
				name: 'Bash-Debug (type in script name)',
				executionDirectory: '${workspaceRoot}',
				scriptPath: '${workspaceRoot}/${command:AskForScriptName}',
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

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.getProgramName', config => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the relative path to bash script.",
			value: (process.platform == "win32") ? "{workspaceRoot}\\path\\to\\script.sh" : "{workspaceRoot}/path/to/script.sh"
		}).then((result)=>{
			return result.replace("{workspaceRoot}", vscode.workspace.rootPath);
		}).then((result)=>{
			return (process.platform == "win32") ? "/mnt/" + result.substr(0, 1).toLowerCase() + result.substr("X:".length).split("\\").join("/") : result;
		});
	}));

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.selectProgramName', config => {

		return vscode.workspace.findFiles("**/*.sh", "").then((uris) => {
			var list = new Array<string>();
			for (var i = 0 ; i < uris.length ; i++){
				list.push(uris[i].fsPath);
			}
			return vscode.window.showQuickPick(list).then((result)=>{
				return (process.platform == "win32") ? "/mnt/" + result.substr(0, 1).toLowerCase() + result.substr("X:".length).split("\\").join("/") : result;
			});
		});
	}));

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.provideInitialConfigurations', config => {

		return vscode.window.showQuickPick(
			["1. Script path should be selected from drop-down list of shell scripts in workspace",
			"2. Script path should be hardcoded in launch task",
			"3. Script path should be typed in by developer when launching"
		]).then((result)=>{
			let selectedConfig: Object;
			switch(parseInt(result.substr(0,1)))
			{
				case 1:
					selectedConfig = initialConfigurations.configuration1;
				case 2:
					selectedConfig = initialConfigurations.configuration2;
				default:
					selectedConfig = initialConfigurations.configuration3;
			}
			return [
				'// Use IntelliSense to learn about possible Mock debug attributes.',
				'// Hover to view descriptions of existing attributes.',
				JSON.stringify(selectedConfig, null, '\t')
			].join('\n');
		})
	}));
}

export function deactivate() {
	// nothing to do
}
