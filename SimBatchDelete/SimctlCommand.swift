//
//  SimctlParser.swift
//

import Foundation

enum SimDeviceState: String, Decodable {
    case shutdown = "Shutdown"
    case booted = "Booted"
}

struct SimDeviceInfo: Decodable {

    let name: String
    let udid: UUID
    let state: SimDeviceState
    let isAvailable: Bool
    let availabilityError: String?
}

//struct SimDeviceType: Decodable {
//}
struct SimRuntimeInfo: Decodable {

    let name: String
    let version: String
    let isAvailable: Bool
    let identifier: String
}
//struct SimDevicePair: Decodable {
//}

struct Simulators: Decodable {

//    let devicetypes: [SimDeviceType]
    let runtimes: [SimRuntimeInfo]
    let devices: [String: [SimDeviceInfo]]
//    let pairs: [UUID: SimDevicePair]
}

struct Toolchain: Decodable {

    let xcodeVersion: String
    let xcodeBuildVersion: String
}

class SimCtlCommand {

    enum ParserError: LocalizedError {
        case jsonDecodeError(Error)
        case emptyResult
        case unexpectedResult(String)
    }

    // MARK: - simctl commands

    func run(then completion: @escaping (Result<Simulators, ParserError>) -> Void) {

        DispatchQueue.global(qos: .background).async {
            let cmd = Process()
            cmd.launchPath = "/usr/bin/xcrun"
            cmd.arguments = [
                "simctl",
                "list",
                "-j"
            ]

            let resultHandler = Pipe()
            cmd.standardOutput = resultHandler
            cmd.terminationHandler = { _ in
                let data = resultHandler.fileHandleForReading.readDataToEndOfFile()
                let decoder = JSONDecoder()
                do {
                    let sims = try decoder.decode(Simulators.self, from: data)
                    completion(.success(sims))
                }
                catch {
                    completion(.failure(.jsonDecodeError(error)))
                }
            }

            cmd.launch()
            cmd.waitUntilExit()

            print("Execution status: \(cmd.terminationStatus)")
        }
    }

    func deleteDevice(_ identifier: UUID, then completion: @escaping (Result<Void, ParserError>) -> Void) {

        DispatchQueue.global(qos: .background).async {
            let cmd = Process()
            cmd.launchPath = "/usr/bin/xcrun"
            cmd.arguments = [
                "simctl",
                "delete",
                identifier.uuidString
            ]

            let resultHandler = Pipe()
            cmd.standardOutput = resultHandler
            cmd.terminationHandler = { _ in
                let data = resultHandler.fileHandleForReading.readDataToEndOfFile()
                if data.count > 0 {
                    if let errorStr = String(data: data, encoding: .utf8) {
                        completion(.failure(.unexpectedResult(errorStr)))
                    }
                    else {
                        completion(.failure(.emptyResult))
                    }
                }
                else {
                    completion(.success(()))
                }
            }

            cmd.launch()
            cmd.waitUntilExit()

            print("Execution status: \(cmd.terminationStatus)")
        }
    }

    // MARK: - Other commands

    func fetchToolchainVersion(then completion: @escaping (Result<Toolchain, ParserError>) -> Void) {

        DispatchQueue.global(qos: .background).async {
            let cmd = Process()
            cmd.launchPath = "/usr/bin/xcodebuild"
            cmd.arguments = [
                "-version"
            ]

            let resultHandler = Pipe()
            cmd.standardOutput = resultHandler
            cmd.terminationHandler = { _ in
                let data = resultHandler.fileHandleForReading.readDataToEndOfFile()

                guard let versionStr = String(data: data, encoding: .utf8) else {
                    completion(.failure(.emptyResult))
                    return
                }

                let parts = versionStr.split(separator: "\n")
                guard parts.count == 2 else {
                    completion(.failure(.unexpectedResult(versionStr)))
                    return
                }

                let xcVersion = String(parts[0])
                let buildVersion = String(parts[1].split(separator: " ").last ?? "")

                completion(.success(Toolchain(xcodeVersion: xcVersion, xcodeBuildVersion: buildVersion)))
            }

            cmd.launch()
            cmd.waitUntilExit()

            print("Execution status: \(cmd.terminationStatus)")
        }
    }
}
