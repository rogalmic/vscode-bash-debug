import { expandPath, getWSLPath, reverseWSLPath, escapeCharactersInBashdbArg } from "./handlePath";

describe("handlePath - expandPath", () => {

    it("stays undefined if path undefined", () => {

        expect(expandPath(undefined, "C:\\Users\\wsh\proj0"))
            .toEqual(undefined);
    });

    it("is not replaced if path absolute", () => {

        expect(expandPath("C:\\Users\\wsh\\proj0\\path\\to\\script.sh", "C:\\Users\\wsh\proj0"))
            .toEqual("C:/Users/wsh/proj0/path/to/script.sh");
    });

    it("is using {workspaceFolder}, on windows", () => {

        expect(expandPath("{workspaceFolder}\\path\\to\\script.sh", "C:\\Users\\wsh\\proj0"))
            .toEqual("C:/Users/wsh/proj0/path/to/script.sh");
    });
});

describe("handlePath - getWSLPath", () => {

    it("stays undefined if path undefined", () => {

        expect(getWSLPath(undefined))
            .toEqual(undefined);
    });

    it("does WSL path conversion if windows path", () => {

        expect(getWSLPath("C:\\Users\\wsh\\proj0\\path\\to\\script.sh"))
            .toEqual("/mnt/c/Users/wsh/proj0/path/to/script.sh");
    });

    it("does no WSL path conversion if path starts with '/'", () => {

        expect(getWSLPath("/mnt/c/Users/wsh/proj0/path/to/script.sh"))
            .toEqual("/mnt/c/Users/wsh/proj0/path/to/script.sh");
    });
});

describe("handlePath - reverseWSLPath", () => {

    it("reverses WSL path", () => {

        expect(reverseWSLPath("/mnt/c/Users/wsh/proj0/path/to/script.sh"))
            .toEqual("C:\\Users\\wsh\\proj0\\path\\to\\script.sh");
    });
});

describe("handlePath - escapeCharactersInBashdbArg", () => {

    it("escapes whitespace for setting bashdb arguments with spaces", () => {

        expect(escapeCharactersInBashdbArg("/pa th/to/script.sh"))
            .toEqual("/pa\\\\0040th/to/script.sh");
    });
});
