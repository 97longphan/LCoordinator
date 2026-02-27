//
//  BaseRouterContextCoordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation

open class BaseRouterContextCoordinator<Context>: BaseRouterCoordinator, ContextCoordinator {
    public let context: Context

    public init(
        router: RouterProtocol,
        presentationStyle: RouterPresentationStyle,
        context: Context
    ) {
        self.context = context
        super.init(router: router, presentationStyle: presentationStyle)
    }

    open override func start() {
        fatalError("Subclasses must override start()")
    }
}
