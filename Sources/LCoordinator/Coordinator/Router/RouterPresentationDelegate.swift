//
//  RouterPresentationDelegate.swift
//  TCB-SoftPOS
//
//  Created by UPP-LONGPHAN-M on 26/10/25.
//

import UIKit

/// Delegate to detect when a presented UIViewController is dismissed
final class RouterPresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    let onDismiss: NavigationBackClosure

    init(onDismiss: @escaping NavigationBackClosure) {
        self.onDismiss = onDismiss
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss()
    }

    deinit {
        print("🔥 RouterPresentationDelegate deinit")
    }
}
