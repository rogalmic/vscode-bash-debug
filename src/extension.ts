'use strict';

import * as vscode from 'vscode';

const initialConfigurations = {
	configuration1: [
	{
		name: 'Bash-Debug (select script from list of sh files)',
		type: 'bashdb',
		request: 'launch',
		program: '${command.SelectScriptName}',
		commandLineArguments: ''
	}],
	configuration2: [
	{
		name: 'Bash-Debug (hardcoded script name)',
		type: 'bashdb',
		request: 'launch',
		program: '${workspaceRoot}/path/to/script.sh',
		commandLineArguments: ''
	}],
	configuration3: [
	{
		name: 'Bash-Debug (type in script name)',
		type: 'bashdb',
		request: 'launch',
		program: '${workspaceRoot}/${command.AskForScriptName}',
		commandLineArguments: ''
	}
	]}

export function activate(context: vscode.ExtensionContext) {

	let disposable1 = vscode.commands.registerCommand('extension.getProgramName', () => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the relative path to bash script.",
			value: "./path/to/script.sh"
		});
	});
	context.subscriptions.push(disposable1);

	let disposable2 = vscode.commands.registerCommand('extension.selectProgramName', () => {

		return vscode.workspace.findFiles("**/*.sh", "").then((uris) => {
			var list = new Array<string>();
			for (var i = 0 ; i < uris.length ; i++){
				list.push(uris[i].fsPath);
			}
			return vscode.window.showQuickPick(list);
		});
	});
	context.subscriptions.push(disposable2);

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.provideInitialConfigurations', () => {
		return vscode.window.showQuickPick(
			["1. Script path should be selected from drop-down list of shell scripts in workspace",
			"2. Script path should be hardcoded in launch task",
			"3. Script path should be typed in by developer when launching"
		]).then((result)=>{
			switch(parseInt(result.substr(0,1)))
			{
				case 1:
					return JSON.stringify(initialConfigurations.configuration1);
				case 2:
					return JSON.stringify(initialConfigurations.configuration2);
				default:
					return JSON.stringify(initialConfigurations.configuration3);
			}
		})
	}));
}

export function deactivate() {
}
