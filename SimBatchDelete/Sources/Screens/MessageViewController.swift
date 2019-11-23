//
//  MessageViewController.swift
//

import Cocoa

final class MessageViewController: NSViewController {

    @IBOutlet private weak var headerLabel: NSTextField!
    @IBOutlet private weak var messageView: NSTextView!

    private var header: String?
    private var message: String?

    func configure(title: String, message: String) {
        self.header = title
        self.message = message
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.headerLabel.stringValue = self.header ?? ""
        self.messageView.string = self.message ?? "No message"
    }
}
