# Change Log

All notable changes to this project will be documented in this file. See [standard-version](https://github.com/conventional-changelog/standard-version) for commit guidelines.

<a name="0.2.4"></a>
## [0.2.4](https://github.com/rogalmic/vscode-bash-debug/compare/v0.2.3...v0.2.4) (2018-09-02)


### Bug Fixes

* Fix for breakpoints handling ([39446cf](https://github.com/rogalmic/vscode-bash-debug/commit/39446cf))



<a name="0.2.3"></a>
## [0.2.3](https://github.com/rogalmic/vscode-bash-debug/compare/v0.2.2...v0.2.3) (2018-08-27)


### Bug Fixes

* Fix file opening second time on debugger break ([938d75f](https://github.com/rogalmic/vscode-bash-debug/commit/938d75f))
* Fix for handling whitespace in source path, requires bashdb fix in place ([f811b57](https://github.com/rogalmic/vscode-bash-debug/commit/f811b57))
* Fix relative source path recognition during debugger break ([07690c5](https://github.com/rogalmic/vscode-bash-debug/commit/07690c5))
* Handle space characters in launch.json args array ([850ce87](https://github.com/rogalmic/vscode-bash-debug/commit/850ce87))



<a name="0.2.2"></a>
## [0.2.2](https://github.com/rogalmic/vscode-bash-debug/compare/v0.2.1...v0.2.2) (2018-08-20)


### Bug Fixes

* Fix crash when debugging inaccessible source file ([af9c3d0](https://github.com/rogalmic/vscode-bash-debug/commit/af9c3d0))



<a name="0.2.1"></a>
## [0.2.1](https://github.com/rogalmic/vscode-bash-debug/compare/v0.2.0...v0.2.1) (2018-08-09)


### Bug Fixes

* Fix breakpoint setting for newest bashdb ([5390d7f](https://github.com/rogalmic/vscode-bash-debug/commit/5390d7f))
* Use defined bash path when stopping debug process ([313bcd6](https://github.com/rogalmic/vscode-bash-debug/commit/313bcd6))



<a name="0.2.0"></a>
# [0.2.0](https://github.com/rogalmic/vscode-bash-debug/compare/v0.1.1...v0.2.0) (2018-04-12)


### Bug Fixes

* fixed error when `cwd` contains space characters ([1a2a9b3](https://github.com/rogalmic/vscode-bash-debug/commit/1a2a9b3))


### Features

* **deploy:** automated changelog generation ([9ea28cb](https://github.com/rogalmic/vscode-bash-debug/commit/9ea28cb))



<a name="0.1.1"></a>
## [0.1.1](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.1.1) (2018-03-17)

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



<a name="0.1.0"></a>
# [0.1.0](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.1.0) (2017-06-13)

- fix deprecated launch.json format



<a name="0.0.7"></a>
## [0.0.7](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.7-alpha.7) (2017-02-25)

- fix redundant watch value data, explain watch expressions (https://github.com/rogalmic/vscode-bash-debug/issues/26)
- fix manual extering of script to run (BashOnWindows case)



<a name="0.0.6"></a>
## [0.0.6](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.6-alpha.6) (2017-02-25)

- fix for watch feature (https://github.com/rogalmic/vscode-bash-debug/issues/26)
- bashdb installation explained (https://github.com/rogalmic/vscode-bash-debug/issues/18)



<a name="0.0.5"></a>
## [0.0.5](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.5-alpha.5) (2017-01-21)

- windows 10 experimental support (verified on insider build 15014)



<a name="0.0.4"></a>
## [0.0.4](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.4-alpha.4) (2017-01-17)

- fix for larger scripts (https://github.com/rogalmic/vscode-bash-debug/issues/22)



<a name="0.0.3"></a>
## [0.0.3](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.3-alpha.3) (2017-01-14)

- remove usage of mktemp (https://github.com/rogalmic/vscode-bash-debug/issues/19)
- partial pause support (not finalized yet)
- preparations for Windows 10 support (once fixes are made in BashOnWindows)



<a name="0.0.2"></a>
## [0.0.2](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.2-alpha.2) (2016-11-06)

- fixed broken initial configurations (for VS Code 1.7.1)
- using single bash process instance as backend
- dropping "tree-kill" usage (using unix pkill directly)



<a name="0.0.1"></a>
## [0.0.1](https://github.com/rogalmic/vscode-bash-debug/releases/tag/v0.0.1-alpha.1) (2016-11-05)

