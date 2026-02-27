//
//  AlertAction.swift
//  TCB-SoftPOS
//
//  Created by UPP-LONGPHAN-M on 26/10/25.
//

import UIKit

public struct AlertAction {
    public let title: String
    public let style: UIAlertAction.Style
    public let handler: (() -> Void)?

    public init(
        title: String,
        style: UIAlertAction.Style = .default,
        handler: (() -> Void)? = nil
    ) {
        self.title = title
        self.style = style
        self.handler = handler
    }
}
