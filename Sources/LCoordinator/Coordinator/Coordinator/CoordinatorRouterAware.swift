//
//  CoordinatorRouterAware.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 7/12/25.
//

import Foundation

/// Protocol for view controllers that need access to coordinator and router
/// Automatically injected by RouterCoordinator during navigation
public protocol CoordinatorRouterAware: AnyObject {
    var coordinator: Coordinator? { get set }
    var parentRouter: RouterProtocol? { get set }
}
