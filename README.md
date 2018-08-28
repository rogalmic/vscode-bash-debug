# VS Code Bash Debug
A bash debugger GUI frontend based on awesome bashdb scripts.

Helpful links:

[https://en.wikipedia.org/wiki/Bash_(Unix_shell)](https://en.wikipedia.org/wiki/Bash_%28Unix_shell%29)

[https://www.gnu.org/software/bash/manual/](https://www.gnu.org/software/bash/manual/)

Sources:

[https://github.com/rogalmic/vscode-bash-debug/](https://github.com/rogalmic/vscode-bash-debug/)

[https://sourceforge.net/p/bashdb/code/ci/master/tree/](https://sourceforge.net/p/bashdb/code/ci/master/tree/)

# Overview
This is a SIMPLE bashdb debugger frontend. Useful for learning bash shell usage and writing simple scripts.

Useful hint: shellcheck extension does a great job with finding common script errors before debugging.

## Usage
1. Select **Debug -> Start Debugging (F5)** to start debugging (if launch.json is not available, it will be created with default configuration)
2. Select **Debug -> Add Configuration** to add custom debug configuration (drop-down, path-input, etc...)

See https://code.visualstudio.com/docs/editor/debugging for general usage.

![Unfortunatly no animation for you :(](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug.gif "Creating launch configuration, then launching debugger for one of scripts in workarea...")

For Windows users:
1. Install [Windows Subsystem for Linux](https://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux)

For macOS users: <br>
Read [here](https://github.com/rogalmic/vscode-bash-debug/wiki/macOS:-avoid-use-of--usr-local-bin-pkill) if your mac has `/usr/local/bin/pkill`.

## Dependencies
1. bash 4.4
2. cat, mkfifo, rm, pkill

## Limitations and known problems
* For now, the debugger supports **only non-interactive scripts** (no stdin, limited [workaround](https://github.com/rogalmic/vscode-bash-debug/wiki/workaround-for-stdin) for this exists)
* Watch variables should be specified with $ at the beginning (this expression is evaluated in bash - for example `${#PWD}` returns path length)
* Currently debugger stops at first command.
