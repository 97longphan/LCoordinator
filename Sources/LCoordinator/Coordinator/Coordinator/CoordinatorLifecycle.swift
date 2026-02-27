//
//  Untitled.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 21/10/25.
//
import UIKit

public enum CoordinatorLifecycle {
    public static func install() {
        UIViewController.installPopObserver()
    }
}
