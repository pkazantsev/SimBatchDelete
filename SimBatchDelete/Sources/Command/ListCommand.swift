//
//  ListCommand.swift
//

import Foundation

enum SimDeviceState: String, Decodable {
    case shutdown = "Shutdown"
    case booted = "Booted"
    case creating = "Creating"
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

enum ParserError: LocalizedError {
    case jsonDecodeError(Error)
    case emptyResult
    case unexpectedResult(String)
}

struct ListCommand: Command {

    private let command = SimCtlCommand(command: .list)

    func run(then completion: @escaping (Result<Simulators, ParserError>) -> Void) {

        command.run { result in
            let data: Data
            switch result {
            case .success(let d):
                data = d
            case .failure(let err):
                completion(.failure(.unexpectedResult(err.message)))
                return
            }

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
}
