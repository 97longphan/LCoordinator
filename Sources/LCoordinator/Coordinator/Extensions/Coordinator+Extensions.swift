//
//  Coordinator+Extensions.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation
extension Coordinator {
    /// Find an ancestor coordinator of specific type by traversing up parent chain
    public func findAncestor<T>(ofType type: T.Type) -> T? {
        var current = self.parentCoordinator
        while current != nil {
            if let match = current as? T {
                return match
            }
            current = current?.parentCoordinator
        }
        return nil
    }
}
