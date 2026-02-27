//
//  BaseCoordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 12/12/25.
//

import Foundation

open class BaseCoordinator: Coordinator {
    /// Parent coordinator (if any) – used for communication or removing child when finished
    weak public var parentCoordinator: Coordinator?

    /// List of active child coordinators
    public var children: [Coordinator] = []

    open func start() {
        fatalError("Subclasses must override `start()`")
    }

    deinit {
        print("❌ [Deinit] \(type(of: self)) deallocated (🧹 Coordinator cleaned up)")
    }
}
