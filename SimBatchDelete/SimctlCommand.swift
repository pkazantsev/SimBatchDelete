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

        execute(path: "/usr/bin/xcrun", args: ["simctl", "list", "-j"]) { data in
            let decoder = JSONDecoder()
            do {
                let sims = try decoder.decode(Simulators.self, from: data)
                completion(.success(sims))
            }
            catch {
                completion(.failure(.jsonDecodeError(error)))
            }
        }
    }

    func deleteDevice(_ identifier: UUID, then completion: @escaping (Result<Void, ParserError>) -> Void) {

        execute(path: "/usr/bin/xcrun", args: ["simctl", "delete", identifier.uuidString]) { data in
            guard data.count > 0 else {
                completion(.success(()))
                return
            }
            if let errorStr = String(data: data, encoding: .utf8) {
                completion(.failure(.unexpectedResult(errorStr)))
            }
            else {
                completion(.failure(.emptyResult))
            }
        }
    }

    // MARK: - Other commands

    func fetchToolchainVersion(then completion: @escaping (Result<Toolchain, ParserError>) -> Void) {

        execute(path: "/usr/bin/xcodebuild", args: ["-version"]) { data in
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
    }

    private func execute(path: String, args: [String], then completion: @escaping (Data) -> Void) {

        DispatchQueue.global(qos: .background).async {
            let cmd = Process()
            cmd.launchPath = path
            cmd.arguments = args

            let resultHandler = Pipe()
            cmd.standardOutput = resultHandler
            cmd.terminationHandler = { _ in
                let data = resultHandler.fileHandleForReading.readDataToEndOfFile()
                completion(data)
            }

            cmd.launch()
        }
    }
}
