# Want to contribute?

Microsoft's documentation for VS Code extensions is suprisingly good (https://code.visualstudio.com/docs/extensions/overview);

## On Linux
Works at least on Kubuntu.

1. install VS Code, npm, nodejs, bashdb (on Ubuntu nodejs-legacy was required) + build essentials
2. clone project
3. open VS Code, select project's folder, open terminal and type "npm install" (this will download dependencies)
4. Run by clicking Ctrl+F5, new VS window will open
5. Create some folder with one script file, then try debugging it by F5

## On Windows 10
All the pieces seems to be there, but for some reason bash support needs some kick off (https://github.com/Microsoft/BashOnWindows/issues/2#issuecomment-209118529). Lets see...

## On OS X
There seems to be bash in OS X, but no way of checking this out now. (https://github.com/rogalmic/vscode-bash-debug/issues/19)