# VS Code Mock Debug
A bash debugger GUI frontend based on awesome bashdb scripts.

# Overview
This is a SIMPLE bashdb debugger frontend. Useful for learning bash shell usage and writing simple scripts.

Hopefully bash will land on 3 leading platforms making this extension very useful.

Sample usage animation:
1. Creating launch configuration with "wizzard"
2. Running debug session

![unfortunatly no animation for you](images/bash-debug.gif "Creating launch configuration, then launching debugger for one of scripts in workarea...")

## Limitations and known problems
* Currently debugger stops at first command.
* Bash unofficial strict mode "set -e" causes debugging script to exit. Consider using "trap 'exit $?' ERR" instead.
* On Windows 10, there is a problem with starting bash without console window (https://github.com/Microsoft/BashOnWindows/issues/2#issuecomment-209118529);