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
    private var selectedSimIds: Set<UUID> = [] {
        didSet {
            if oldValue.isEmpty != self.selectedSimIds.isEmpty {
                self.deleteSelectedSimsButton.isEnabled = !self.selectedSimIds.isEmpty
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

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction private func run(_ sender: Any) {
        self.parser.run { [weak self] result in
            print("Parser returned \(result)")

            switch result {
            case .success(let sims):
                self?.sims = sims
                let runtimes = Dictionary(grouping: sims.runtimes) { $0.identifier }
                // Map devices and the OS versions
                self?.simulators = sims.devices.flatMap { d -> [SimViewModel] in
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
            case .failure(let error):
                print("Parser returned error: \(error)")
                self?.sims = nil
                self?.simulators = []
            }
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
    }

    @IBAction private func selectionChanged(_ sender: NSButton) {
        let rowIndex = self.tableView.row(for: sender)
        let sim = self.simulators[rowIndex]

        print("\(sim.name) got \(sender.state == .on ? "selected" : "deselected")")

        switch sender.state {
        case .on:
            self.selectedSimIds.insert(sim.identifier)
        case .off:
            self.selectedSimIds.remove(sim.identifier)
        default:
            break
        }
    }

    @IBAction private func deleteSelectedDevices(_ sender: NSButton) {
        for sim in self.simulators {
            // TODO: Call the 'delete' command
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
            checkbox.state = self.selectedSimIds.contains(sim.identifier) ? .on : .off
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
}

