//
//  BaseContextCoordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 12/12/25.
//

import Foundation

open class BaseContextCoordinator<Context>: BaseCoordinator, ContextCoordinator {
    public let context: Context

    public init(
        context: Context
    ) {
        self.context = context
        super.init()
    }

    open override func start() {
        fatalError("Subclasses must override start()")
    }
}
