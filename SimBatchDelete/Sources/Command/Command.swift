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
    let expectingLongOutput: Bool

    func run(then completion: @escaping (Result<Data, CommandError>) -> Void) {

        DispatchQueue.global(qos: .userInitiated).async {

            let cmd = Process()
            cmd.launchPath = self.cmdPath
            cmd.arguments = self.arguments
            cmd.qualityOfService = .userInitiated

            let output: FileHandle
            do {
                output = try setOutput(to: cmd)
            } catch {
                completion(.failure(CommandError(message: error.localizedDescription)))
                return
            }

            let errorHandler = Pipe()
            cmd.standardError = errorHandler

            cmd.terminationHandler = { _ in
                let resultData: Data
                do {
                    resultData = try readOutput(from: output)
                } catch {
                    completion(.failure(CommandError(message: error.localizedDescription)))
                    return
                }

                if !resultData.isEmpty {
                    completion(.success(resultData))
                } else {
                    let error = errorHandler.fileHandleForReading.readDataToEndOfFile()
                    completion(.failure(CommandError(message: String(data: error, encoding: .utf8)!)))
                }
            }

            cmd.launch()
        }
    }

    private func setOutput(to cmd: Process) throws -> FileHandle {
        let output: FileHandle
        if expectingLongOutput {
            let handle = try makeTempFileHandle(url: tempFileUrl)
            cmd.standardOutput = handle
            output = handle
        } else {
            let resultHandler = Pipe()
            cmd.standardOutput = resultHandler
            output = resultHandler.fileHandleForReading
        }
        return output
    }

    private func readOutput(from handle: FileHandle) throws -> Data {
        let resultData: Data
        if expectingLongOutput {
            resultData = try Data(contentsOf: tempFileUrl)
            try FileManager.default.removeItem(at: tempFileUrl)
        } else {
            resultData = handle.readDataToEndOfFile()
        }
        return resultData
    }

    private func makeTempFileHandle(url: URL) throws -> FileHandle {
        if FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            try Data().write(to: url, options: .atomic)
        } else {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        return try FileHandle(forWritingTo: url)
    }

    private var tempFileUrl: URL {
        FileManager
            .default
            .temporaryDirectory
            .appendingPathComponent("sim_batch_delete_output.txt")
    }
}
