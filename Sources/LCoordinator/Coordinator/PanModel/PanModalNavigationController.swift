//
//  PanModalNavigationController.swift
//  TCB-SoftPOS
//
//  Created by UPP-LONGPHAN-M on 9/11/25.
//

import UIKit

/// Custom navigation controller for PanModal bottom sheets
/// Delegates pan properties to topViewController and updates height on push/pop
public final class PanModalNavigationController: UINavigationController, RouterPanModalPresentable {

    public init(root: UIViewController) {
        super.init(nibName: nil, bundle: nil)
        viewControllers = [root]
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // Disable swipe back to avoid conflict with pan-to-dismiss
        interactivePopGestureRecognizer?.delegate = self
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - HPanModalPresentable

    public var allowsTapToDismiss: Bool {
        (topViewController as? HPanModalPresentable)?.allowsTapToDismiss ?? true
    }

    public var panScrollable: UIScrollView? {
        (topViewController as? HPanModalPresentable)?.panScrollable
    }

    public var shortFormHeight: HPanModalHeight {
        (topViewController as? HPanModalPresentable)?.shortFormHeight ?? .contentHeight(0)
    }

    public var longFormHeight: HPanModalHeight {
        (topViewController as? HPanModalPresentable)?.longFormHeight ?? .contentHeight(0)
    }

    public var cornerRadius: CGFloat {
        (topViewController as? HPanModalPresentable)?.cornerRadius ?? 16
    }

    public var allowsDragToDismiss: Bool {
        (topViewController as? HPanModalPresentable)?.allowsDragToDismiss ?? true
    }

    public var onDismissRouter: (() -> Void)?

    public func panModalWillDismiss() {
        onDismissRouter?()
    }

    public override func pushViewController(
        _ viewController: UIViewController,
        animated: Bool
    ) {
        super.pushViewController(viewController, animated: animated)
        // Update pan modal height for new VC
        panModalSetNeedsLayoutUpdate()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panModalTransition(to: .longForm)
        }
    }

    public override func popViewController(animated: Bool) -> UIViewController? {
        let popped = super.popViewController(animated: animated)

        // Update pan modal height after pop
        panModalSetNeedsLayoutUpdate()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.panModalTransition(to: .longForm)
        }

        return popped
    }

}

extension PanModalNavigationController: UIGestureRecognizerDelegate {
    /// Disable swipe back gesture to prevent conflict with pan-to-dismiss
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
