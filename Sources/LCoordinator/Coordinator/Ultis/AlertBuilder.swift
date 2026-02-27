//
//  AlertDrawable.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation
import UIKit
struct AlertDrawable: Drawable {
    let viewController: UIViewController?
    var canDelegate: Bool { false }

    init(alert: UIAlertController) {
        self.viewController = alert
    }
}

final class AlertBuilder {
    private let alert: UIAlertController

    init(
        title: String?,
        message: String?,
        style: UIAlertController.Style = .alert
    ) {
        alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: style
        )
    }

    @discardableResult
    func addAction(
        title: String,
        style: UIAlertAction.Style = .default,
        handler: (() -> Void)? = nil
    ) -> AlertBuilder {
        let action = UIAlertAction(title: title, style: style) { _ in handler?() }
        alert.addAction(action)
        return self
    }

    func build() -> AlertDrawable {
        return AlertDrawable(alert: alert)
    }
}
