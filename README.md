# VS Code Bash Debug
A bash debugger GUI frontend based on awesome bashdb scripts.

**Install bashdb** before usage:
* [apt](https://en.wikipedia.org/wiki/Advanced_Packaging_Tool) package manager
```{r, engine='bash'}
sudo apt-get install bashdb
```
* [yum](https://en.wikipedia.org/wiki/Yellowdog_Updater,_Modified) package manager
```{r, engine='bash'}
sudo yum install bashdb
```
* installation from sources (advanced):
```{r, engine='bash'}
tar -xvf bashdb-*.tar.gz
cd bashdb-*
./configure
make
sudo make install
```
* verification
```{r, engine='bash'}
bashdb --version
```

Helpful links:

[https://en.wikipedia.org/wiki/Bash_(Unix_shell)](https://en.wikipedia.org/wiki/Bash_%28Unix_shell%29)

[https://www.gnu.org/software/bash/manual/](https://www.gnu.org/software/bash/manual/)

Sources:

[https://github.com/rogalmic/vscode-bash-debug/](https://github.com/rogalmic/vscode-bash-debug/)

[https://sourceforge.net/p/bashdb/code/ci/master/tree/](https://sourceforge.net/p/bashdb/code/ci/master/tree/)

# Overview
This is a SIMPLE bashdb debugger frontend. Useful for learning bash shell usage and writing simple scripts.

Hopefully bash will land on 3 leading platforms making this extension very useful.

## Usage
1. Press ctrl+shift+P (cmd+shift+P) and run "Debug: Open launch.json"
2. Select "Bash Debug" and choose the configuration you prefer
3. Running debug session

See https://code.visualstudio.com/docs/editor/debugging for general usage.

NOTE: step 2. is skipped if `${workspaceFolder}/.vscode/launch.json` exists. Rename it temporary before, to create the configuration.

![unfortunatly no animation for you](images/bash-debug.gif "Creating launch configuration, then launching debugger for one of scripts in workarea...")

## Dependencies
1. bashdb 4.3
2. cat, mkfifo, rm, pkill

## Limitations and known problems
* Watch variables should be specified with $ at the beginning (this expression is evaluated in bash - for example `${#PWD}` returns path length)
* Currently debugger stops at first command.
* Executing "set -e" causes debugging script to exit (bashdb limitation). Consider using "trap 'exit $?' ERR" instead.
* Newest Windows 10 insider build 15014 seems to be working with some hacks (https://github.com/Microsoft/BashOnWindows/issues/2#issuecomment-209118529, https://github.com/Microsoft/BashOnWindows/issues/1489);
