//
//  BaseRouterCoordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation
open class BaseRouterCoordinator: RouterCoordinator {
    /// Parent coordinator (if any) – used for communication or removing child when finished
    weak public var parentCoordinator: Coordinator?

    /// List of active child coordinators
    public var children: [Coordinator] = []

    /// Current router used for navigation (push/present) in this flow
    public var router: RouterProtocol

    /// Default presentation style for this coordinator: `.push` or `.present`
    public let presentationStyle: RouterPresentationStyle

    /// Initially equals router, saved before router is replaced with new one (for modal presentation)
    public var parentRouter: RouterProtocol

    public init(
        router: RouterProtocol,
        presentationStyle: RouterPresentationStyle = .push
    ) {
        self.router = router
        self.presentationStyle = presentationStyle
        self.parentRouter = router
    }

    open func start() {
        fatalError("Subclasses must override `start()`")
    }

    deinit {
        print("❌ [Deinit] \(type(of: self)) deallocated (🧹 Coordinator cleaned up)")
    }
}
