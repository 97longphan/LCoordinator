//
//  BaseAppCoordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation
import UIKit

public protocol FlowRoute {}

public protocol FlowFactory {
    associatedtype Route: FlowRoute
    func make(_ route: Route, parent: Coordinator?) -> AppFlowBuildResult
}
