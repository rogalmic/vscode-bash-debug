# VS Code Bash Debug
A bash debugger GUI frontend based on awesome `bashdb` scripts (bashdb now included in package).

# Overview
This is a SIMPLE bashdb debugger frontend. Useful for learning bash shell usage and writing simple scripts.

Useful hint: shellcheck extension does a great job with finding common script errors before debugging.

## Usage
1. Select **Debug -> Add Configuration** to add custom debug configuration (drop-down, path-input, etc...)
1. Select **Debug -> Start Debugging (F5)** to start debugging

See https://code.visualstudio.com/docs/editor/debugging for general usage.

## Sample features
- Debugging auto configuration via `launch.json`

[![Unfortunatly no animation for you :(](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-launch-autoconfig.gif "Creating launch configuration, then launching debugger for one of scripts in workarea...")](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-launch-autoconfig.gif)

- Simple debugging in hello world application

[![Unfortunatly no animation for you :(](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-hello-world.gif "Creating launch configuration, then launching debugger for one of scripts in workarea...")](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-hello-world.gif)

- Standard input handling via terminal

[![Unfortunatly no animation for you :(](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-stdin-usage.gif "Creating launch configuration, then launching debugger for one of scripts in workarea...")](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-stdin-usage.gif)

- Pause support while script is running

[![Unfortunatly no animation for you :(](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-pause-support.gif "Creating launch configuration, then launching debugger for one of scripts in workarea...")](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-pause-support.gif)

- Advanced "Watch" and "Debug console" usage

[![Unfortunatly no animation for you :(](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-watch-advanced.gif "Creating launch configuration, then launching debugger for one of scripts in workarea...")](https://raw.githubusercontent.com/rogalmic/vscode-bash-debug/gif/images/bash-debug-samp-watch-advanced.gif)


For Windows users:
- Install [Windows Subsystem for Linux](https://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux)
- Terminal has problems with spaces in paths when powershell is used, use [WSL bash](https://github.com/Microsoft/vscode/issues/22317) instead

For macOS users:
- Read [here](https://github.com/rogalmic/vscode-bash-debug/wiki/macOS:-avoid-use-of--usr-local-bin-pkill) if your mac has `/usr/local/bin/pkill`.

## Dependencies
1. `bash 4.3` or `bash 4.4`
2. `cat`, `mkfifo`, `rm`, `pkill`

## Limitations and known problems
* Currently debugger stops at first command
* `$0` variable shows path to bashdb
* Older `bash` versions ( `3.0` - `4.2` ) are not tested/supported, but might work™
