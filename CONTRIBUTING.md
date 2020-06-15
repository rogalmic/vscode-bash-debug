# Contributing

Microsoft's documentation for VS Code extensions is suprisingly good (https://code.visualstudio.com/docs/extensions/overview);

## On Linux

Works at least on Kubuntu.

1. install VS Code, `npm`, `nodejs`, optionally `bashdb` (some time ago `nodejs-legacy` was required) + build essentials
1. clone project
1. disable auto carriage return `git config core.autocrlf false; git reset --hard`
1. open VS Code, select project's folder, open terminal and type `npm install` (this will download dependencies)
1. Run by clicking **Ctrl+F5**, new VS window will open
1. Create some folder with one script file, then try debugging it by **F5** (to debug bashDebug.ts, read [this](https://code.visualstudio.com/docs/extensions/example-debuggers#_development-setup-for-mock-debug) -> basically set `Extension + Server` in debug pane, then set `"debugServer": 4711` configuration in launch.json of bash project)

## On Windows 10

All the pieces seem to be there, but for some reason bash support needs some kick off (https://github.com/Microsoft/BashOnWindows/issues/2#issuecomment-209118529).

Currently, with some hacks, seems to be working on Windows 10. The scripts are executed in bash@linux realm,so all the paths inside scripts need to refer to linux filesystem (`/mnt/c/..`).

## On OS X

Seeems to be working when path to `pkill` is changed. MacOS seems to have bash v.3 by default, this project aims to support bash versions >= 4.3.

## Build CI

Using Travis CI (https://travis-ci.org/rogalmic/vscode-bash-debug)

- Every push to master will create a release in github with `vsix` package for testing
- Every tag pushed to master matching `v1.2.3` will trigger a deploy to VSCode extension repo with this version.
  - Remember to use [proper commit messages](https://github.com/conventional-changelog/standard-version#commit-message-convention-at-a-glance).
  - Keep version in project.json same as version in git tag, best to achieve by running `npm run release -- --release-as minor` to bump version and create commit with [proper tag](https://docs.npmjs.com/cli/version#git-tag-version) at the same time.
  - Push the tag `git push origin v1.2.3`, this will start the publish build in [TravisCI](https://travis-ci.org/rogalmic/vscode-bash-debug).
