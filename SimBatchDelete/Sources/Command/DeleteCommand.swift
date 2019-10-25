//
//  DeleteCommand.swift
//

import Foundation

struct DeleteCommand: Command {

    private let command: SimCtlCommand

    init(deviceId: UUID) {
        command = SimCtlCommand(command: .delete(deviceId: deviceId))
    }

    func run(then completion: @escaping (Result<Void, CommandError>) -> Void) {

        command.run { result in
            completion(result.map { _ in () })
        }
    }
}
