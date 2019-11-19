//
//  Command.swift
//

import Foundation

protocol Command {

    associatedtype Success
    associatedtype Failure: Error

    func run(then completion: @escaping (Result<Success, Failure>) -> Void)
}

struct CommandError: LocalizedError {

    let message: String
}

struct ConsoleCommand: Command {

    let cmdPath: String
    let arguments: [String]

    func run(then completion: @escaping (Result<Data, CommandError>) -> Void) {

        DispatchQueue.global(qos: .background).async {
            let cmd = Process()
            cmd.launchPath = self.cmdPath
            cmd.arguments = self.arguments

            let resultHandler = Pipe()
            cmd.standardOutput = resultHandler
            let errorHandler = Pipe()
            cmd.standardError = errorHandler
            cmd.terminationHandler = { _ in
                let data = resultHandler.fileHandleForReading.readDataToEndOfFile()
                if !data.isEmpty {
                    // Data first – ignore the error if data is there
                    completion(.success(data))
                }
                else {
                    let error = errorHandler.fileHandleForReading.readDataToEndOfFile()
                    if !error.isEmpty {
                        completion(.failure(CommandError(message: String(data: error, encoding: .utf8)!)))
                    }
                    else {
                        completion(.failure(CommandError(message: "Error getting devices list: no message")))
                    }
                }
            }

            cmd.launch()
        }
    }
}
