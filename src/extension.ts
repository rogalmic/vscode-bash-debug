/*---------------------------------------------------------
 * Copyright (C) Microsoft Corporation. All rights reserved.
 *--------------------------------------------------------*/

'use strict';

import * as vscode from 'vscode';

const initialConfigurations = {
	version: '0.2.0',
	configurations: [
	{
		name: 'Bash-Debug',
		type: 'bashdb',
		request: 'launch',
		program: '${workspaceRoot}/${command.AskForProgramName}',
		stopOnEntry: true
	}
]}

export function activate(context: vscode.ExtensionContext) {

	let disposable = vscode.commands.registerCommand('extension.getProgramName', () => {
		return vscode.window.showInputBox({
			placeHolder: "Please enter the relative path to bash script.",
			value: "./path/to/script.sh"
		});
	});
	context.subscriptions.push(disposable);

	// TODO: list all bash scripts instead of uncomfortable input
	// let disposable2 = vscode.commands.registerCommand('extension.getProgramName', () => {
	// 	return vscode.window.showQuickPick(
	// 		["path1", "path2"]
	// 	);
	// });
	// context.subscriptions.push(disposable2);

	context.subscriptions.push(vscode.commands.registerCommand('extension.bash-debug.provideInitialConfigurations', () => {
		return JSON.stringify(initialConfigurations);
	}));
}

export function deactivate() {
}
