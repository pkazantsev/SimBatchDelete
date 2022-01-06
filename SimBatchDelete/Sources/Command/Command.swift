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
            if #available(OSX 10.13, *) {
                cmd.executableURL = URL(fileURLWithPath: self.cmdPath)
            } else {
                cmd.launchPath = self.cmdPath
            }
            cmd.arguments = self.arguments

            // Result pipe

            let resultHandler = Pipe()
            cmd.standardOutput = resultHandler

            var resultData = Data()
            // NOTE: Without the readability handler, the process may never finish!
            resultHandler.fileHandleForReading.readabilityHandler = { fh in
                let data = fh.availableData

                if !data.isEmpty {
                    resultData += data
                }
            }

            // Error pipe

            let errorHandler = Pipe()
            cmd.standardError = errorHandler

            var errorData = Data()
            // NOTE: Without the readability handler, the process may never finish!
            errorHandler.fileHandleForReading.readabilityHandler = { fh in
                let data = fh.availableData

                if !data.isEmpty {
                    errorData += data
                }
            }

            // On process completion

            cmd.terminationHandler = { _ in
//                let data = resultHandler.fileHandleForReading.readDataToEndOfFile()
                if !resultData.isEmpty {
                    // Data first – ignore the error if data is there
                    completion(.success(resultData))
                }
                else {
//                    let error = errorHandler.fileHandleForReading.readDataToEndOfFile()
                    if !errorData.isEmpty {
                        completion(.failure(CommandError(message: String(data: errorData, encoding: .utf8)!)))
                    }
                    else {
                        completion(.failure(CommandError(message: "Error while executing a command: no message")))
                    }
                }
            }

            if #available(OSX 10.13, *) {
                do {
                    try cmd.run()
                }
                catch {
                    print("Cannot execute command: \(self.cmdPath)")
                }
            } else {
                cmd.launch()
            }
        }
    }
}
