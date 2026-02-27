//
//  RouterCoordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import UIKit

// MARK: - Router Presentation Style

/// Defines how a coordinator presents its view controller
public enum RouterPresentationStyle: Equatable {
    /// Push into navigation stack
    case push

    /// Present modally with specific style
    case present(UIModalPresentationStyle)

    /// Present as bottom sheet using PanModal
    case panModel

    /// No presentation (embedded or root)
    case none
}

// MARK: - RouterCoordinator Protocol

/// Protocol for coordinators that use a Router for navigation
public protocol RouterCoordinator: Coordinator {
    /// Current router used by this coordinator
    var router: RouterProtocol { get set }

    /// Presentation style (push / present / panModel)
    var presentationStyle: RouterPresentationStyle { get }

    /// Parent coordinator's router (for dismiss/pop back)
    var parentRouter: RouterProtocol { get set }
}

// MARK: - Navigation Support

extension RouterCoordinator {

    /// Execute navigation to a new view controller
    ///
    /// - Parameters:
    ///   - viewController: ViewController to display
    ///   - isAnimated: Whether to animate (default = true)
    ///   - coordinator: Current coordinator performing navigation
    ///   - onFinish: Callback when screen is popped or dismissed
    public func perform<V: UIViewController>(
        _ viewController: V,
        isAnimated: Bool = true,
        from coordinator: Coordinator,
        onFinish: (() -> Void)? = nil
    ) {
        // Print full coordinator tree from root
        printFullCoordinatorTree()

        // Inject router and coordinator if VC conforms to CoordinatorRouterAware
        if let vc = viewController as? CoordinatorRouterAware {
            vc.coordinator = coordinator

            // ⚠️ Always use self.router (CURRENT router of this coordinator)
            // - Push/None: self.router === self.parentRouter (same instance)
            // - Present/PanModal: self.router is router before change
            //   → VC needs this router to dismiss back correctly
            // - Segment Child: VC receives segment's router
            //   → VC never pushes directly, always via coordinator delegate
            //   → Coordinator decides: use self.router (segment) or self.parentRouter (full screen)
            vc.parentRouter = self.router
        }

        switch presentationStyle {

        case .panModel, .present:

            let presentedNav: UINavigationController

            switch presentationStyle {
            case .panModel:
                presentedNav = PanModalNavigationController(root: viewController)

            case .present(let style):
                let nav = UINavigationController(rootViewController: viewController)
                nav.modalPresentationStyle = style
                presentedNav = nav

            default:
                fatalError("Unexpected case")
            }

            let presentingRouter = Router(navigationController: presentedNav)

            router.present(
                drawable: presentedNav,
                coordinator: coordinator,
                isAnimated: isAnimated,
                onDismiss: onFinish
            )

            // Save current router to parentRouter before changing
            // → Used to dismiss/pop back to parent coordinator
            parentRouter = router
            // Replace router with new presentingRouter (for modal's navigation stack)
            router = presentingRouter
        case .push:

            // MARK: - Push Presentation

            router.push(
                drawable: viewController,
                to: coordinator,
                isAnimated: isAnimated,
                onNavigateBack: onFinish
            )

        case .none:
            break
        }
    }
}
