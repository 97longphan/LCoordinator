//
//  BaseAppCoordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation
import UIKit

open class BaseAppCoordinator<Factory: FlowFactory>: Coordinator {
    public weak var parentCoordinator: Coordinator?
    public var children: [Coordinator] = []

    public let window: UIWindow
    public let factory: Factory

    public typealias Route = Factory.Route

    public init(window: UIWindow, factory: Factory) {
        self.window = window
        self.factory = factory
    }

    open func initialRoute() -> Route { fatalError("Must override initialRoute()") }

    open func start() {
        navigate(to: initialRoute())
    }

    public func navigate(to route: Route) {
        let buildResult = factory.make(route, parent: self)

        let rootCoordinator = buildResult.rootCoordinator
        let childCoordinators = buildResult.childCoordinators
        let rootViewController = buildResult.rootViewController

        rootCoordinator.parentCoordinator = self

        children = [rootCoordinator]

        rootCoordinator.children.append(contentsOf: childCoordinators)

        rootCoordinator.start()

        childCoordinators.forEach { child in
            child.parentCoordinator = rootCoordinator
            child.start()
        }

        window.rootViewController = rootViewController
        window.makeKeyAndVisible()
    }
}
