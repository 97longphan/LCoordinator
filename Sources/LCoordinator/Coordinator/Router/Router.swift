//
//  Router.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import UIKit

// MARK: - Drawable Protocol

/// Represents any entity that can be displayed (typically a UIViewController)
public protocol Drawable {
    /// The UIViewController that can be presented or pushed
    var viewController: UIViewController? { get }

    /// Indicates whether this VC allows delegate assignment for presentation callbacks
    var canDelegate: Bool { get }
}

// MARK: - UIViewController + Drawable

extension UIViewController: Drawable {
    public var viewController: UIViewController? { self }
    public var canDelegate: Bool { true }
}

// MARK: - PanModal Support

/// Specialized interface for PanModal that supports a dismissal callback
public protocol RouterPanModalPresentable: HPanModalPresentable {
    /// Called when the PanModal is dismissed
    var onDismissRouter: (() -> Void)? { get set }
}

/// Typealias representing a UIViewController that conforms to RouterPanModalPresentable
public typealias RouterPanModalViewController = UIViewController & RouterPanModalPresentable

// MARK: - Typealiases

/// Closure triggered when navigating back or dismissing
public typealias NavigationBackClosure = () -> Void

// MARK: - RouterProtocol

/// Defines all navigation behaviors of a Router
public protocol RouterProtocol: AnyObject {
    var navigationController: UINavigationController { get }

    func push(
        drawable: Drawable,
        to coordinator: Coordinator,
        isAnimated: Bool,
        onNavigateBack: NavigationBackClosure?
    )

    func present(
        drawable: Drawable,
        coordinator: Coordinator,
        isAnimated: Bool,
        onDismiss: NavigationBackClosure?
    )

    func pop(isAnimated: Bool)

    func popToRootCoordinator(isAnimated: Bool)

    func popToCoordinator(
        coordinator: Coordinator,
        isAnimated: Bool,
        completion: (() -> Void)?
    )

    func dismiss<T: Coordinator>(
        ofType type: T.Type,
        isAnimated: Bool,
        completion: (() -> Void)?
    )

    func dismiss(
        coordinator: Coordinator,
        isAnimated: Bool,
        completion: (() -> Void)?
    )

    func dismissAllPresented(
        isAnimated: Bool,
        completion: (() -> Void)?
    )

    func showAlert(
        title: String,
        message: String,
        from coordinator: Coordinator,
        animated: Bool,
        actions: [AlertAction]
    )
}

// MARK: - RouterContext (Private)

/// Keeps contextual information for each Coordinator — used for cleanup and callback execution
private struct RouterContext {
    weak var viewController: UIViewController?
    var onNavigateBack: NavigationBackClosure?
    var presentationDelegate: RouterPresentationDelegate?
    var coordinatorType: Coordinator.Type
}

// MARK: - Router Implementation

public final class Router: NSObject, RouterProtocol {

    // MARK: Properties

    public let navigationController: UINavigationController
    fileprivate var coordinatorContexts: [ObjectIdentifier: RouterContext] = [:]

    // MARK: Init

    public init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
    }
}

// MARK: - Push Navigation

public extension Router {

    /// Push a UIViewController into the navigation stack
    ///
    /// **Flow:**
    /// 1. Extract VC from drawable
    /// 2. Register auto-cleanup callback (triggered when user swipes back or taps back button)
    /// 3. Store coordinator context (for manual cleanup and tracking)
    /// 4. Push VC to navigation stack
    func push(
        drawable: Drawable,
        to coordinator: Coordinator,
        isAnimated: Bool,
        onNavigateBack: NavigationBackClosure?
    ) {
        guard let vc = drawable.viewController else { return }

        // Auto cleanup when user navigates back (via swizzled didMove method)
        vc.onPop = { [weak self, weak vc] in
            guard let self, let vc else { return }
            self.executeClosure(for: vc)
        }

        // Store context for manual cleanup & tracking
        let id = ObjectIdentifier(coordinator)
        coordinatorContexts[id] = RouterContext(
            viewController: vc,
            onNavigateBack: onNavigateBack,
            presentationDelegate: nil,
            coordinatorType: type(of: coordinator)
        )

        // Execute push
        navigationController.pushViewController(vc, animated: isAnimated)
    }

    /// Pop back to previous view controller
    func pop(isAnimated: Bool) {
        navigationController.popViewController(animated: isAnimated)
    }

    /// Pop back to the root view controller (first VC in stack)
    ///
    /// **Flow:**
    /// 1. Get all VCs except root (first one)
    /// 2. Cleanup contexts for all VCs that will be popped
    /// 3. Execute pop to root
    func popToRootCoordinator(isAnimated: Bool) {
        guard !navigationController.viewControllers.isEmpty else {
            print("⚠️ No view controllers in the stack")
            return
        }

        let currentStack = navigationController.viewControllers
        let poppedVCs = currentStack.dropFirst() // All except root

        // Cleanup contexts before pop
        for vc in poppedVCs {
            executeClosure(for: vc)
        }

        // Execute pop to root
        navigationController.popToRootViewController(animated: isAnimated)
    }

    /// Pop to a specific coordinator's view controller
    ///
    /// **Flow:**
    /// 1. Find target VC from coordinator context
    /// 2. Get all VCs after target (will be popped)
    /// 3. Cleanup contexts for VCs that will be removed
    /// 4. Execute pop with completion callback
    func popToCoordinator(
        coordinator: Coordinator,
        isAnimated: Bool,
        completion: (() -> Void)?
    ) {
        let id = ObjectIdentifier(coordinator)
        guard let toVC = coordinatorContexts[id]?.viewController else {
            print("⚠️ No ViewController found for coordinator \(coordinator)")
            return
        }

        let currentStack = navigationController.viewControllers
        guard let index = currentStack.firstIndex(of: toVC) else {
            print("⚠️ Target ViewController not found in stack")
            return
        }

        // Cleanup all VCs after target index (will be popped)
        let poppedVCs = currentStack.suffix(from: index + 1)
        for vc in poppedVCs {
            executeClosure(for: vc)
        }

        // Execute pop with completion callback
        CATransaction.begin()
        CATransaction.setCompletionBlock { completion?() }
        navigationController.popToViewController(toVC, animated: isAnimated)
        CATransaction.commit()
    }
}

// MARK: - Modal Presentation

public extension Router {

    /// Present a view controller modally (supports both regular modal and PanModal)
    ///
    /// **Flow:**
    /// 1. Extract VC from drawable
    /// 2. Create presentation delegate (to detect user swipe-down dismiss)
    /// 3. Store coordinator context for tracking
    /// 4. Handle presentation based on type:
    ///    - PanModal: Use PanModal library (bottom sheet)
    ///    - Regular: Use standard UIKit modal presentation
    func present(
        drawable: Drawable,
        coordinator: Coordinator,
        isAnimated: Bool,
        onDismiss: NavigationBackClosure?
    ) {
        guard let vc = drawable.viewController else { return }

        var delegate: RouterPresentationDelegate? = nil

        // Create delegate to detect user swipe-down dismiss (for regular modals)
        if drawable.canDelegate {
            delegate = RouterPresentationDelegate(onDismiss: { [
                weak self,
                weak vc
            ] in
                guard let self, let vc else { return }
                self.executeClosure(for: vc)
            })
        }

        // Store context for manual dismiss & tracking
        let id = ObjectIdentifier(coordinator)
        coordinatorContexts[id] = RouterContext(
            viewController: vc,
            onNavigateBack: onDismiss,
            presentationDelegate: delegate, // Keep strong ref to delegate
            coordinatorType: type(of: coordinator)
        )

        // Handle PanModal presentation (bottom sheet)
        if let panModalVC = vc as? RouterPanModalViewController {
            panModalVC.onDismissRouter = { [weak self, weak vc] in
                guard let self, let vc else { return }
                self.executeClosure(for: vc)
            }
            navigationController.topViewController?.presentPanModal(panModalVC)
        } else {
            // Handle regular modal presentation
            if let delegate {
                vc.presentationController?.delegate = delegate
            }

            if let topVC = topMostViewController(from: navigationController) {
                topVC.present(vc, animated: isAnimated)
            } else {
                print("⚠️ No top-most VC found for presentation")
            }
        }
    }
}

// MARK: - Dismiss Methods

public extension Router {

    /// Dismiss a coordinator by its type
    ///
    /// **Use case:** Parent coordinator wants to dismiss a specific child by type
    ///
    /// **Flow:**
    /// 1. Find first coordinator matching type in contexts
    /// 2. Get its view controller
    /// 3. Execute cleanup (triggers onNavigateBack callback)
    /// 4. Dismiss VC (auto-dismisses all its children)
    ///
    /// **Note:** Dismissing a presented VC automatically dismisses all VCs it presented
    func dismiss<T: Coordinator>(
        ofType type: T.Type,
        isAnimated: Bool,
        completion: (() -> Void)?
    ) {
        // Find coordinator context by type
        guard let (id, ctx) = coordinatorContexts.first(where: { $0.value.coordinatorType == type }) else {
            print("⚠️ No coordinator of type \(type)")
            return
        }

        // Get view controller
        guard let vc = ctx.viewController else {
            coordinatorContexts.removeValue(forKey: id)
            return
        }

        // Cleanup context & execute callback
        executeClosure(for: vc)

        // Dismiss VC (auto-dismisses children)
        vc.dismiss(animated: isAnimated, completion: completion)
    }

    /// Dismiss a specific coordinator instance
    ///
    /// **Use case:** Dismiss when you have direct coordinator reference
    ///
    /// **Flow:**
    /// 1. Get coordinator ID (ObjectIdentifier)
    /// 2. Find VC from context
    /// 3. Execute cleanup (triggers onNavigateBack callback)
    /// 4. Dismiss VC
    ///
    /// **Note:** Must be called from parent: `parentRouter.dismiss(self)`
    func dismiss(
        coordinator: Coordinator,
        isAnimated: Bool,
        completion: (() -> Void)?
    ) {
        let id = ObjectIdentifier(coordinator)
        guard let vc = coordinatorContexts[id]?.viewController else { return }

        // Cleanup context & execute callback
        executeClosure(for: vc)

        // Dismiss VC
        vc.dismiss(animated: isAnimated, completion: completion)
    }

    /// Dismiss all presented modals and return to the root presenter
    ///
    /// **Use case:** A presents B → B presents C → C triggers action → A dismisses all (B & C)
    ///
    /// **Flow:**
    /// 1. Find topmost VC in entire app (recursively)
    /// 2. Walk down presentation chain to find root presenter
    /// 3. Collect all VCs in presentation chain (will be dismissed)
    /// 4. Filter coordinators whose VCs are in that chain
    /// 5. Dismiss from root presenter → dismisses all at once
    /// 6. Cleanup all affected coordinator contexts
    ///
    /// **Why collect before dismiss:**
    /// - After dismiss, VCs might be deallocated
    /// - We need to know which coordinators to cleanup
    /// - Collecting IDs beforehand ensures accurate cleanup
    func dismissAllPresented(
        isAnimated: Bool,
        completion: (() -> Void)?
    ) {
        guard let topVC = topMostViewController(from: navigationController) else {
            completion?()
            return
        }

        // Walk down to find root presenter (bottom of presentation chain)
        var rootPresenter = topVC.presentingViewController
        while let presenter = rootPresenter?.presentingViewController {
            rootPresenter = presenter
        }

        // Collect all VCs in presentation chain (from root presenter upward)
        let presentedVCs = collectPresentedViewControllers(from: rootPresenter)

        // Find coordinator IDs whose VCs will be dismissed
        let dismissedCoordinatorIDs = coordinatorContexts
            .filter { _, ctx in
                guard let vc = ctx.viewController else { return false }
                return presentedVCs.contains(vc)
            }
            .map { $0.key }

        // Dismiss all modals at once from root
        rootPresenter?.dismiss(animated: isAnimated) { [weak self] in
            guard let self = self else { return }

            // Cleanup all dismissed coordinators
            for id in dismissedCoordinatorIDs {
                guard let ctx = self.coordinatorContexts[id] else { continue }
                ctx.onNavigateBack?()
                self.coordinatorContexts.removeValue(forKey: id)
            }

            completion?()
        }
    }
}

// MARK: - Alert

public extension Router {

    /// Present an alert through the Router
    ///
    /// **Flow:**
    /// 1. Build UIAlertController using AlertBuilder
    /// 2. Add all actions to alert
    /// 3. Wrap alert in Drawable
    /// 4. Present using standard present() method
    ///
    /// **Note:** Alert dismissal doesn't trigger cleanup (onDismiss = nil)
    func showAlert(
        title: String,
        message: String,
        from coordinator: Coordinator,
        animated: Bool,
        actions: [AlertAction]
    ) {
        // Build alert with actions
        let builder = AlertBuilder(title: title, message: message)
        for action in actions {
            builder.addAction(
                title: action.title,
                style: action.style,
                handler: action.handler
            )
        }

        // Present alert (no cleanup needed on dismiss)
        let alertDrawable = builder.build()
        present(
            drawable: alertDrawable,
            coordinator: coordinator,
            isAnimated: animated,
            onDismiss: nil
        )
    }
}

// MARK: - Private Helpers - Cleanup

private extension Router {

    /// Execute cleanup for a view controller
    ///
    /// **Flow:**
    /// 1. Find coordinator context by VC reference (identity comparison ===)
    /// 2. Execute onNavigateBack callback (notifies coordinator to cleanup)
    /// 3. Remove context from dictionary
    ///
    /// **Note:** Called automatically when VC is popped/dismissed
    func executeClosure(for viewController: UIViewController) {
        if let (key, context) = coordinatorContexts.first(where: { $0.value.viewController === viewController }) {
            context.onNavigateBack?() // Notify coordinator
            coordinatorContexts.removeValue(forKey: key) // Remove context
        }
    }
}

// MARK: - Private Helpers - View Hierarchy

private extension Router {

    /// Recursively find the topmost visible view controller in the app
    ///
    /// **Logic:**
    /// 1. If VC has presented VC → recurse into presented VC
    /// 2. Handle container VCs (UINavigationController, UITabBarController)
    /// 3. Return the deepest visible VC
    ///
    /// **Use case:** Find where to present modals/alerts
    func topMostViewController(from root: UIViewController?) -> UIViewController? {
        guard let root else { return nil }

        // Check if presenting another VC
        if let presented = root.presentedViewController {
            // Handle container VCs
            if let nav = presented as? UINavigationController {
                return topMostViewController(from: nav.visibleViewController)
            } else if let tab = presented as? UITabBarController {
                return topMostViewController(from: tab.selectedViewController)
            } else {
                return topMostViewController(from: presented)
            }
        }

        // Handle root container VCs
        if let nav = root as? UINavigationController {
            return topMostViewController(from: nav.visibleViewController)
        } else if let tab = root as? UITabBarController {
            return topMostViewController(from: tab.selectedViewController)
        }

        // Return leaf VC
        return root
    }

    /// Collect all view controllers in the presentation chain
    ///
    /// **Flow:**
    /// 1. Start from root presenter
    /// 2. Walk up presentation chain (presentedViewController)
    /// 3. For each VC, add it to result
    /// 4. If VC is UINavigationController, add all VCs in its stack
    /// 5. Continue until no more presented VCs
    ///
    /// **Use case:** Identify all VCs that will be dismissed by dismissAllPresented
    func collectPresentedViewControllers(from presenter: UIViewController?) -> [UIViewController] {
        var result: [UIViewController] = []
        var current = presenter?.presentedViewController

        // Walk up presentation chain
        while let vc = current {
            result.append(vc)

            // Include all VCs in navigation stack
            if let nav = vc as? UINavigationController {
                result.append(contentsOf: nav.viewControllers)
            }

            // Move to next presented VC
            current = vc.presentedViewController
        }

        return result
    }
}
