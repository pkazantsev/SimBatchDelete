//
//  AppsListViewController.swift
//

import Cocoa

final class AppsListViewController: NSViewController {

    @IBOutlet private weak var tableView: NSTableView!

    private var appsList: [AppInfo] = []

    func configure(with appsList: [AppInfo]) {
        self.appsList = appsList
        self.tableView?.reloadData()
    }

    @IBAction private func showContainer(_ sender: NSButton) {
        // TODO: Implement
    }
    @IBAction private func showAppBundle(_ sender: NSButton) {
        // TODO: Implement
    }
}

extension AppsListViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return appsList.count
    }
}

private enum Column: String {

    case appName
    case appBundleId
}

extension AppsListViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        guard let column = tableColumn, let columnId = Column(rawValue: column.identifier.rawValue) else { return nil }
        guard let cell = tableView.makeView(withIdentifier: column.identifier, owner: nil) else { return nil }

        let app = self.appsList[row]

        switch columnId {
        case .appName:
            if let textField = (cell as? NSTableCellView)?.textField {
                textField.stringValue = app.title
            }
        case .appBundleId:
            if let textField = (cell as? NSTableCellView)?.textField {
                textField.stringValue = app.bundleId
            }
        }

        return cell
    }
}
