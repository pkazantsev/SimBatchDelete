//
//  ViewController.swift
//

import Cocoa

struct SimViewModel {

    let identifier: UUID

    let name: String
    let version: String
    let available: String
    let state: String
    let comment: String
}

enum Column: String {

    case checkbox
    case name
    case version
    case isAvailable
    case state
    case comment
}

class ViewController: NSViewController {

    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var loadButton: NSButton!
    @IBOutlet private weak var deleteSelectedSimsButton: NSButton!
    @IBOutlet private weak var cmdLineToolsVersionLabel: NSTextField!

    private lazy var parser = SimCtlCommand()

    private var sims: Simulators? {
        didSet {
            if self.sims != nil && oldValue == nil {
                DispatchQueue.main.async {
                    self.loadButton.title = "Reload"
                }
            }
        }
    }
    private var simulators: [SimViewModel] = []
    private var selectedSims: [UUID: SimViewModel] = [:] {
        didSet {
            if oldValue.isEmpty != self.selectedSims.isEmpty {
                self.deleteSelectedSimsButton.isEnabled = !self.selectedSims.isEmpty
            }
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        self.parser.fetchToolchainVersion { [weak self] result in
            switch result {
            case .success(let tc):
                DispatchQueue.main.async {
                    self?.cmdLineToolsVersionLabel.stringValue = "\(tc.xcodeVersion) (\(tc.xcodeBuildVersion))"
                }
            case .failure:
                break
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        self.reloadData()
    }

    @IBAction private func run(_ sender: Any) {
        self.reloadData()
    }

    @IBAction private func selectionChanged(_ sender: NSButton) {
        let rowIndex = self.tableView.row(for: sender)
        let sim = self.simulators[rowIndex]

        print("\(sim.name) got \(sender.state == .on ? "selected" : "deselected")")

        switch sender.state {
        case .on:
            self.selectedSims[sim.identifier] = sim
        case .off:
            self.selectedSims.removeValue(forKey: sim.identifier)
        default:
            break
        }
    }

    @IBAction private func deleteSelectedDevices(_ sender: NSButton) {
        self.deleteAllCheckboxedSimulators()
    }

    private func reloadData() {
        self.loadButton?.isEnabled = false
        self.parser.run { [weak self] result in
            print("Parser returned \(result)")

            switch result {
            case .success(let sims):
                self?.processSimulators(sims)
            case .failure(let error):
                print("Parser returned error: \(error)")
                self?.sims = nil
                self?.simulators = []
            }
            DispatchQueue.main.async {
                self?.loadButton?.isEnabled = true
                self?.tableView.reloadData()
            }
        }
    }

    private func processSimulators(_ sims: Simulators) {
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
}

extension ViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.simulators.count
    }
}

extension ViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard let column = tableColumn, let columnId = Column(rawValue: column.identifier.rawValue) else { return nil }
        guard let cell = tableView.makeView(withIdentifier: column.identifier, owner: nil) else { return nil }

        let sim = self.simulators[row]

        if case .checkbox = columnId {
            guard let checkbox = cell as? NSButton else { return nil }
            checkbox.state = self.selectedSims[sim.identifier] != nil ? .on : .off
        }
        else if let textField = (cell as? NSTableCellView)?.textField {

            switch columnId {
            case .checkbox:
                break
            case .name:
                textField.stringValue = sim.name
            case .version:
                textField.stringValue = sim.version
            case .isAvailable:
                textField.stringValue = sim.available
            case .state:
                textField.stringValue = sim.state
            case .comment:
                textField.stringValue = sim.comment
            }
        }

        return cell
    }
    
    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 51 else {
            return
        }
        self.deleteCurrenltySelectedSimulator()
    }
    
}

extension ViewController {
    private func deleteAllCheckboxedSimulators() {
        let simsToDelete = self.selectedSims
        self.selectedSims.removeAll()
        var simsToDeleteCount = simsToDelete.count
        for sim in simsToDelete.values {
            self.parser.deleteDevice(sim.identifier) { [weak self] result in
                DispatchQueue.main.async {
                    simsToDeleteCount -= 1
                    switch result {
                    case .success:
                        print("\(sim.name) delete successful")
                    case .failure(let err):
                        print("\(sim.name) deletion error: \(err)")
                    }
                    if (simsToDeleteCount <= 0) {
                        self?.reloadData()
                    }
                }
            }
        }
    }
    
    private func deleteCurrenltySelectedSimulator() {
        let selectedRowIndex = self.tableView.selectedRow
        guard selectedRowIndex <= self.simulators.count else {
            return
        }
        let simulator = self.simulators[selectedRowIndex]
        self.parser.deleteDevice(simulator.identifier) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("\(simulator.name) delete successful")
                case .failure(let err):
                    print("\(simulator.name) deletion error: \(err)")
                }
                self?.reloadData()
            }
        }
    }

}

