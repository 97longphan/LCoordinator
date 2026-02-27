//
//  ViewController+Extensions.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 21/10/25.
//

import ObjectiveC
import UIKit

private var onPopKey: UInt8 = 0

/// Trigger onPop callback when user taps back button or swipes back
extension UIViewController {
    var onPop: (() -> Void)? {
        get { objc_getAssociatedObject(self, &onPopKey) as? (() -> Void) }
        set { objc_setAssociatedObject(
            self,
            &onPopKey,
            newValue,
            .OBJC_ASSOCIATION_COPY_NONATOMIC
        ) }
    }

    static func installPopObserver() {
        guard self === UIViewController.self else { return }

        let original = class_getInstanceMethod(
            self,
            #selector(didMove(toParent:))
        )
        let swizzled = class_getInstanceMethod(
            self,
            #selector(_coordinator_didMove(toParent:))
        )

        if let original, let swizzled {
            method_exchangeImplementations(original, swizzled)
        }
    }

    @objc private func _coordinator_didMove(toParent parent: UIViewController?) {
        _coordinator_didMove(toParent: parent)

        // Auto trigger when popped from navigation stack
        if parent == nil {
            onPop?()
        }
    }
}
