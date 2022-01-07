//
//  SimCtlCommand.swift
//

import Foundation

struct SimCtlCommand: Command {

    enum Subcommand {

//        case create              // Create a new device.
//        case clone               // Clone an existing device.
//        case upgrade             // Upgrade a device to a newer runtime.
        /// Delete spcified devices, unavailable devices, or all devices.
        case delete(deviceId: UUID)
//        case pair                // Create a new watch and phone pair.
//        case unpair              // Unpair a watch and phone pair.
//        case pair_activate       // Set a given pair as active.
//        case erase               // Erase a device's contents and settings.
//        case boot                // Boot a device.
//        case shutdown            // Shutdown a device.
//        case rename              // Rename a device.
//        case getenv              // Print an environment variable from a running device.
//        case openurl             // Open a URL in a device.
//        case addmedia            // Add photos, live photos, videos, or contacts to the library of a device.
//        case install             // Install an app on a device.
//        case uninstall           // Uninstall an app from a device.
//        case get_app_container   // Print the path of the installed app's container
//        case launch              // Launch an application by identifier on a device.
//        case terminate           // Terminate an application by identifier on a device.
//        case spawn               // Spawn a process by executing a given executable on a device.
        /// List available devices, device types, runtimes, or device pairs.
        ///
        /// Returns JSON representation.
        case list
//        case icloud_sync         // Trigger iCloud sync on a device.
//        case pbsync              // Sync the pasteboard content from one pasteboard to another.
//        case pbcopy              // Copy standard input onto the device pasteboard.
//        case pbpaste             // Print the contents of the device's pasteboard to standard output.
//        case help                // Prints the usage for a given subcommand.
//        case io                  // Set up a device IO operation.
//        case diagnose            // Collect diagnostic information and logs.
//        case logverbose          // enable or disable verbose logging for a device
//        case status_bar          // Set or clear status bar overrides
    }

    private let command: ConsoleCommand

    init(command: Subcommand) {
        self.command = ConsoleCommand(
            cmdPath: "/usr/bin/xcrun",
            arguments: ["simctl"] + Self.arguments(for: command),
            expectingLongOutput: command.expectingLongOutput
        )
    }

    func run(then completion: @escaping (Result<Data, CommandError>) -> Void) {
        command.run(then: completion)
    }

    private static func arguments(for command: Subcommand) -> [String] {
        switch command {
        case .delete(let deviceId):
            return ["delete", deviceId.uuidString]
        case .list:
            return ["list", "-j"]
        }
    }
}

private extension SimCtlCommand.Subcommand {
    var expectingLongOutput: Bool {
        switch self {
        case .delete:
            return false
        case .list:
            return true
        }
    }
}
