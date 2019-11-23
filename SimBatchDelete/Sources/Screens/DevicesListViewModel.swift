//
//  DevicesListViewModel.swift
//

import Foundation

enum DeviceSelectionState: String {

    case selected
    case deselected
}

class DevicesListViewModel {

    private var sims: Simulators?

    private(set) var simulators: [SimViewModel] = []
    private(set) var selectedSims: Set<UUID> = Set()

    func getToolchainVersion(then completion: @escaping (Result<String, CommandError>) -> Void) {
        ToolchainVersionCommand().run { result in
            switch result {
            case .success(let tc):
                DispatchQueue.main.async {
                    completion(.success("\(tc.xcodeVersion) (\(tc.xcodeBuildVersion))"))
                }
            case .failure(let error):
                let message: String
                switch error {
                case .emptyResult: message = "No error"
                case .unexpectedResult(let msg): message = msg
                case .jsonDecodeError(let err): message = String(describing: err)
                }
                DispatchQueue.main.async {
                    completion(.failure(.init(message: message)))
                }
            }
        }
    }

    func reloadDevicesList(then completion: @escaping () -> Void) {
        ListCommand().run { [weak self] result in
            print("Parser returned \(result)")
            guard let strongSelf = self else {
                return
            }

            switch result {
            case .success(let sims):
                strongSelf.processDevicesList(sims)
            case .failure(let error):
                print("Parser returned error: \(error)")
                strongSelf.sims = nil
                strongSelf.simulators = []
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    private func processDevicesList(_ sims: Simulators) {
        self.sims = sims
        let runtimes = Dictionary(grouping: sims.runtimes) { $0.identifier }
        // Map devices and the OS versions
        self.simulators = sims.devices.flatMap { d -> [SimViewModel] in
            let (runtimeId, devices) = d
            let runtime = runtimes[runtimeId]?.first

            let runtimeName = runtime?.name ?? "Unavailable"
            let comment = runtime == nil ? runtimeId.split(separator: ".").last.map { $0 + ": " } ?? "" : ""

            return devices.map {
                return SimViewModel(identifier: $0.udid, name: $0.name, version: runtimeName, available: $0.isAvailable ? "Yes" : "No", state: $0.state.rawValue, comment: comment + ($0.availabilityError ?? ""))
            }
        }.sorted { (m1, m2) -> Bool in
            if m1.version == m2.version {
                return m1.name.compare(m2.name, options: [.caseInsensitive]) == .orderedAscending
            }
            else if m1.version == "Unavailable" {
                // Unavailable goes to the bottom
                return false
            }
            else if m2.version == "Unavailable" {
                // Unavailable goes to the bottom
                return true
            }
            else {
                return m1.version.compare(m2.version, options: [.caseInsensitive]) == .orderedAscending
            }
        }
    }

    func changeDeviceSelection(at index: Int, state: DeviceSelectionState) {
        let sim = self.simulators[index]

        print("\(sim.name) got \(state)")

        switch state {
        case .selected:
            self.selectedSims.insert(sim.identifier)
        case .deselected:
            self.selectedSims.remove(sim.identifier)
        }
    }

    func deleteAllCheckboxedSimulators(then completion: @escaping () -> Void) {
        let simsToDelete = self.selectedSims
        self.selectedSims.removeAll()
        var simsToDeleteCount = simsToDelete.count
        for simId in simsToDelete {
            DeleteCommand(deviceId: simId).run { result in
                DispatchQueue.main.async {
                    simsToDeleteCount -= 1
                    switch result {
                    case .success:
                        print("\(simId) delete successful")
                    case .failure(let err):
                        print("\(simId) deletion error: \(err)")
                    }
                    if (simsToDeleteCount <= 0) {
                        completion()
                    }
                }
            }
        }
    }

    func deleteSimulator(at index: Int, then completion: @escaping () -> Void) {
        let sim = self.simulators[index]
        DeleteCommand(deviceId: sim.identifier).run { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("\(sim.name) delete successful")
                case .failure(let err):
                    print("\(sim.name) deletion error: \(err)")
                }
                completion()
            }
        }
    }

    func installedApps(forDeviceAt index: Int, then completion: @escaping ([AppInfo]) -> Void) {
        let sim = self.simulators[index]
        AppsListCommand(deviceId: sim.identifier).run { result in
            switch result {
            case .success(let apps):
                completion(apps)
            case .failure(let err):
                print("Could not fetch apps list: \(err.localizedDescription)")
            }
        }
    }
}
