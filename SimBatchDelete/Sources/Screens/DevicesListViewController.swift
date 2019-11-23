//
//  DevicesListViewController.swift
//

import Cocoa

// for maintaining key code for keyboard entry.
enum KeyCodes {
    static let delete: UInt16 = 0x33
}

class DevicesListViewController: NSViewController {

    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var loadButton: NSButton!
    @IBOutlet private weak var deleteSelectedSimsButton: NSButton!
    @IBOutlet private weak var cmdLineToolsVersionLabel: NSTextField!

    private let viewModel: DevicesListViewModel = DevicesListViewModel()

    private var rowContextMenu: NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show installed apps", action: #selector(showInstalledAppsList), keyEquivalent: "a"))
        return menu
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.menu = self.rowContextMenu
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        self.viewModel.getToolchainVersion { [unowned self] result in

            switch result {
            case .success(let versionStr):
                self.cmdLineToolsVersionLabel.stringValue = versionStr
                self.reloadDevicesList()
            case .failure(let err):
                let dialog = self.makeMessageViewController(title: "Toolchain error", message: err.message)
                self.presentAsSheet(dialog)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
        case .command where event.keyCode == KeyCodes.delete:
            self.deleteCurrenltySelectedSimulator()
        default:
            break
        }
    }

    @IBAction private func run(_ sender: Any) {
        self.reloadDevicesList()
    }

    @IBAction private func selectionChanged(_ sender: NSButton) {
        let rowIndex = self.tableView.row(for: sender)

        switch sender.state {
        case .on:
            self.viewModel.changeDeviceSelection(at: rowIndex, state: .selected)
        case .off:
            self.viewModel.changeDeviceSelection(at: rowIndex, state: .deselected)
        default:
            break
        }

        self.deleteSelectedSimsButton.isEnabled = !self.viewModel.selectedSims.isEmpty
    }

    @IBAction private func deleteSelectedDevices(_ sender: NSButton) {
        self.deleteAllCheckboxedSimulators()
    }

    private func makeMessageViewController(title: String, message: String) -> MessageViewController {
        let vc = self.storyboard!.instantiateController(withIdentifier: "ModalSystemMessage") as! MessageViewController
        vc.configure(title: title, message: message)
        return vc
    }

    @objc
    private func showInstalledAppsList() {
        let index = self.tableView.selectedRow
        guard index >= 0 && index < self.viewModel.simulators.count else {
            return
        }

        self.viewModel.installedApps(forDeviceAt: index) { [weak self] apps in
            // TODO: Show some sheet with the list
        }
    }
}

extension DevicesListViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.viewModel.simulators.count
    }
}

extension DevicesListViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard let column = tableColumn, let columnId = Column(rawValue: column.identifier.rawValue) else { return nil }
        guard let cell = tableView.makeView(withIdentifier: column.identifier, owner: nil) else { return nil }

        let sim = self.viewModel.simulators[row]

        if case .checkbox = columnId {
            guard let checkbox = cell as? NSButton else { return nil }
            checkbox.state = self.viewModel.selectedSims.contains(sim.identifier) ? .on : .off
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

extension DevicesListViewController {

    private func reloadDevicesList() {
        self.loadButton?.isEnabled = false

        self.viewModel.reloadDevicesList { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.loadButton?.title = "Reload"
            strongSelf.loadButton?.isEnabled = true
            strongSelf.tableView?.reloadData()
        }
    }

    private func deleteAllCheckboxedSimulators() {
        self.viewModel.deleteAllCheckboxedSimulators { [weak self] in
            self?.reloadDevicesList()
        }
    }

    private func deleteCurrenltySelectedSimulator() {
        let index = self.tableView.selectedRow
        guard index >= 0 && index < self.viewModel.simulators.count else {
            return
        }

        self.viewModel.deleteSimulator(at: index) { [weak self] in
            self?.reloadDevicesList()
        }
    }

}

