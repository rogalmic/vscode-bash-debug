import { join } from 'path';

export function expandPath(path?: string, rootPath?: string): string | undefined {

    if (!path) {
        return undefined;
    }

    if (rootPath) {
        path = path.replace("{workspaceFolder}", <string>rootPath).split("\\").join("/");
    }

    return path;
}

export function getWSLPath(path?: string): string | undefined {

    if (!path) {
        return undefined;
    }

    if (!path.startsWith("/")) {
        path = "/mnt/" + path.substr(0, 1).toLowerCase() + path.substr("X:".length).split("\\").join("/");
    }

    return path;
}

export function reverseWSLPath(wslPath: string): string {

    if (wslPath.startsWith("/mnt/")) {
        return wslPath.substr("/mnt/".length, 1).toUpperCase() + ":" + wslPath.substr("/mnt/".length + 1).split("/").join("\\");
    }

    return wslPath.split("/").join("\\");
}

export function getWSLLauncherPath(useInShell: boolean): string {

    if (useInShell) {
        return "wsl.exe";
    }

    return process.env.hasOwnProperty('PROCESSOR_ARCHITEW6432') ?
        join("C:", "Windows", "sysnative", "wsl.exe") :
        join("C:", "Windows", "System32", "wsl.exe");
}

export function escapeCharactersInBashdbArg(path: string): string {
    return path.replace(/\s/g, (m) => "\\\\" + ("0000" + m.charCodeAt(0).toString(8)).slice(-4));
}

