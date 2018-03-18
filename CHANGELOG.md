# Change Log

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

0.1.1
=====
## [Bugfix release v0.1.1](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.1.1)
- update attributes in `launch.json`
  - *BREAKING* change attribute names
    - `bashDbPath` -> `pathBashdb`
    - `bashPath` -> `pathBash`
    - `scriptPath` -> `program`
  - add `cwd` attribute to set working directory (#25, #32)
  - add `trace` attribute to enable logging of the Debug Adapter Protocol
  - fix default `launch.json` generation after breaking change in Microsoft's debug adapter interface (#39, #41, #45, #46)
- dynamic default `pathBash` generation, allowing 32bit and 64bit VSCode usage on Windows
- automated deployment (possibility to download pre-release extension's vsix directly from [github](https://github.com/rogalmic/vscode-bash-debug/releases))

0.1.0
=====
## [Bugfix release v0.1.0](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.1.0)
- fix deprecated launch.json format

0.0.7
=====
## [Bugfix release v0.0.7](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.7-alpha.7)
- fix redundant watch value data, explain watch expressions (https://github.com/rogalmic/vscode-bash-debug/issues/26)
- fix manual extering of script to run (BashOnWindows case)

0.0.6
=====
## [Bugfix release v0.0.6](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.6-alpha.6)
- fix for watch feature (https://github.com/rogalmic/vscode-bash-debug/issues/26)
- bashdb installation explained (https://github.com/rogalmic/vscode-bash-debug/issues/18)

0.0.5
=====
## [Feature release v0.0.5](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.5-alpha.5)
- windows 10 experimental support (verified on insider build 15014)

0.0.4
=====
## [Bugfix release v0.0.4](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.4-alpha.4)
- fix for larger scripts (https://github.com/rogalmic/vscode-bash-debug/issues/22)

0.0.3
=====
## [Bugfix release v0.0.3](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.3-alpha.3)
- remove usage of mktemp (https://github.com/rogalmic/vscode-bash-debug/issues/19)
- partial pause support (not finalized yet)
- preparations for Windows 10 support (once fixes are made in BashOnWindows)

0.0.2
=====
## [Bugfix release v0.0.2](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.2-alpha.2)
- fixed broken initial configurations (for VS Code 1.7.1)
- using single bash process instance as backend
- dropping "tree-kill" usage (using unix pkill directly)

0.0.1
=====
## [Initial release v0.0.1](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.1-alpha.1)

