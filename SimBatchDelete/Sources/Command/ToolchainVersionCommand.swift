//
//  ToolchainVersionCommand.swift
//

import Foundation

struct ToolchainVersionCommand: Command {

    private let command = ConsoleCommand(cmdPath: "/usr/bin/xcodebuild",
                                         arguments: ["-version"])

    func run(then completion: @escaping (Result<Toolchain, ParserError>) -> Void) {

        command.run { result in
            let data: Data
            switch result {
            case .success(let d):
                data = d
            case .failure(let err):
                completion(.failure(.unexpectedResult(err.message)))
                return
            }

            guard let versionStr = String(data: data, encoding: .utf8), !versionStr.isEmpty else {
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
}
