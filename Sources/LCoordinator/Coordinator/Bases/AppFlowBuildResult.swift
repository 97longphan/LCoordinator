//
//  AppFlowBuildResult.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 16/12/25.
//

import UIKit

public struct AppFlowBuildResult {
    public let rootViewController: UIViewController
    public let rootCoordinator: Coordinator
    public let childCoordinators: [Coordinator]

    public init(
        rootViewController: UIViewController,
        rootCoordinator: Coordinator,
        childCoordinators: [Coordinator] = []
    ) {
        self.rootViewController = rootViewController
        self.rootCoordinator = rootCoordinator
        self.childCoordinators = childCoordinators
    }
}
