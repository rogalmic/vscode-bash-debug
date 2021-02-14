import { validatePath, validatePathResult, _validatePath } from "./bashRuntime";

describe("bashRuntime - validatePath", () => {

    it("returns proper error message when wrong cwd", () => {

        expect(validatePath("non-exist-directory", "bash", "type", "type", "type", "type"))
            .toContain("Error: cwd (non-exist-directory) does not exist.\n");
    });

    it("returns empty message if correct data ", () => {

        expect(validatePath("./", "bash", "type", "type", "type", "type"))
            .toEqual("");
    });
});

describe("bashRuntime - _validatePath", () => {

    it("returns success when all data correct", () => {

        expect(_validatePath("./", "bash", "type", "type", "type", "type"))
            .toEqual([validatePathResult.success, ""]);
    });

    it("returns notExistCwd when cwd incorrect", () => {

        expect(_validatePath("non-exist-directory", "bash", "type", "type", "type", "type"))
            .toEqual([validatePathResult.notExistCwd, ""]);
    });

    it("returns notFoundBash when bash path incorrect", () => {

        expect(_validatePath("./", "invalid-bash-path", "type", "type", "type", "type"))
            .toEqual([validatePathResult.notFoundBash, "/bin/bash: invalid-bash-path: command not found\n"]);
    });

    it("returns notFoundBashdb when bashdb path incorrect", () => {

        expect(_validatePath("./", "bash", "invalid-bashdb-path", "type", "type", "type"))
            .toEqual([validatePathResult.notFoundBashdb, "bash: line 0: type: invalid-bashdb-path: not found\n"]);
    });

    it("returns notFoundCat when cat path incorrect", () => {

        expect(_validatePath("./", "bash", "type", "invalid-cat-path", "type", "type"))
            .toEqual([validatePathResult.notFoundCat, "bash: line 0: type: invalid-cat-path: not found\n"]);
    });

    it("returns notFoundMkfifo when mkfifo path incorrect", () => {

        expect(_validatePath("./", "bash", "type", "type", "invalid-mkfifo-path", "type"))
            .toEqual([validatePathResult.notFoundMkfifo, "bash: line 0: type: invalid-mkfifo-path: not found\n"]);
    });

    it("returns notFoundPkill when pkill path incorrect", () => {

        expect(_validatePath("./", "bash", "type", "type", "type", "invalid-pkill-path"))
            .toEqual([validatePathResult.notFoundPkill, "bash: line 0: type: invalid-pkill-path: not found\n"]);
    });

    it("returns notFoundBash when all data incorrect", () => {

        expect(_validatePath("invalid-path", "invalid-path", "invalid-path", "invalid-path", "invalid-path", "invalid-path"))
            .toEqual([validatePathResult.notFoundBash, "/bin/bash: invalid-path: command not found\n"]);
    });

    it("returns timeout when timeout", () => {

        expect(_validatePath("./", "bash", "", "", "", "", 1))
            .toEqual([validatePathResult.timeout, ""]);
    });
});