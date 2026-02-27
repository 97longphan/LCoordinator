//
//  ContextCoordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 11/1/26.
//

public protocol ContextCoordinator: AnyObject {
    associatedtype Context
    var context: Context { get }
}