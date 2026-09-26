import AppKit
import Foundation
import ReadMeCore

let bundleID = "me.read.app"
guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
    fputs("read.me app not found (me.read.app). Build the app bundle first.\n", stderr)
    exit(1)
}

let config = NSWorkspace.OpenConfiguration()
let group = DispatchGroup()
group.enter()

if let path = CLIArgs.resolvedPath(from: CommandLine.arguments) {
    NSWorkspace.shared.open([path], withApplicationAt: appURL, configuration: config) { _, error in
        if let error {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
        group.leave()
    }
} else {
    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
        if let error {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }
        group.leave()
    }
}

_ = group.wait(timeout: .now() + 10)
