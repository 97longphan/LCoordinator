//
//  Coordinator.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation
import UIKit

/// Protocol for coordinators that manage multiple children
/// but only one child is visible at a time (active/visible).
///
/// **Examples:**
/// - `TabbarCoordinator` → active child is the selected tab
/// - `PageCoordinator` → active child is the current page
///
/// **Note:** Regular coordinators (push/modal flows) DON'T need this protocol.
/// Only implement when there's a concept of "one visible child at a time".
public protocol ActiveChildCoordinator: Coordinator {
    var activeChildCoordinator: Coordinator? { get }
}

public protocol Coordinator: AnyObject {
    var parentCoordinator: Coordinator? { get set }
    var children: [Coordinator] { get set }

    func start()
    func childDidFinish(_ child: Coordinator)
}

extension Coordinator {
    public func childDidFinish(_ child: Coordinator) {
        print("🧹 [Coordinator] Removed child: \(type(of: child))")
        children.removeAll { $0 === child }
    }
}

extension Coordinator {
    /// Traverse to root coordinator and print the full tree
    public func printFullCoordinatorTree() {
        #if DEBUG
            var root: Coordinator = self
            while let parent = root.parentCoordinator {
                root = parent
            }
            print("🌳 ========== Coordinator Tree ==========")
            root.printCoordinatorTree()
            print("🌳 =======================================")
        #endif
    }

    public func printCoordinatorTree(level: Int = 0) {
        let indent = String(repeating: "  ", count: level)

        if let routerCoordinator = self as? RouterCoordinator {
            let routerType = type(of: routerCoordinator.router)

            let styleDescription: String
            switch routerCoordinator.presentationStyle {
            case .push:
                styleDescription = "push"
            case .present(let modalStyle):
                styleDescription = "modal(\(modalStyle))"
            case .panModel:
                styleDescription = "panModel"
            case .none:
                styleDescription = "none"
            }

            print("\(indent)📍 \(type(of: self)) 📦 Router: \(routerType) [\(styleDescription)]")
        } else {
            print("\(indent)📍 \(type(of: self))")
        }

        for child in children {
            child.printCoordinatorTree(level: level + 1)
        }
    }
}

extension Coordinator {
    /// Find a coordinator of specific type in the coordinator tree.
    /// Recursively searches self and all children.
    public func findCoordinator<T: Coordinator>(as type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }
        for child in children {
            if let found = child.findCoordinator(as: type) {
                return found
            }
        }
        return nil
    }

    /// Returns the deepest (most nested) coordinator currently visible in the coordinator tree.
    ///
    /// **Logic:**
    /// 1. If `self` conforms to `ActiveChildCoordinator` (e.g., `TabbarCoordinator`, `SegmentCoordinator`):
    ///    - First, check if any coordinator is presented/pushed on top of the container
    ///    - If yes → recurse into that coordinator (it's visible on top)
    ///    - If no → recurse into the `activeChildCoordinator` (currently selected tab/page/segment)
    /// 2. If not `ActiveChildCoordinator`, recurse into `children.last` (last pushed/presented coordinator)
    ///    - **Important:** Skips embedded children (plugins/widgets with `.none` + shared router)
    ///    - Only recurses into actual navigation destinations
    /// 3. If no navigable children exist, return `self`
    ///
    /// **Use Case:**
    /// Determines the currently visible coordinator at the deepest level.
    /// Essential for deep linking to ensure navigation happens from the correct visible screen.
    ///
    /// **Example:**
    /// ```
    /// MHHomeCoordinator [push]
    ///   ├─ MHHomeHeaderPluginCoordinator [none, shared router] ← Skipped (embedded)
    ///   └─ MHHomeReportPluginCoordinator [none, shared router] ← Skipped (embedded)
    /// deepestVisibleCoordinator → MHHomeCoordinator (correct for deeplink push)
    /// ```
    public var deepestVisibleCoordinator: Coordinator {
        // Handle ActiveChildCoordinator (TabBar/Segment/Page coordinators)
        if let active = self as? ActiveChildCoordinator {
            // Check if something is presented/pushed on top of the container
            if let topCoordinator = findCoordinatorOnTopOfContainer(activeChild: active.activeChildCoordinator) {
                return topCoordinator.deepestVisibleCoordinator
            }

            // Nothing on top → navigate into active child (selected tab/page/segment)
            if let activeChild = active.activeChildCoordinator {
                return activeChild.deepestVisibleCoordinator
            }
        }

        // Handle regular coordinators: last child is the visible one
        // Skip embedded children (plugins/components with .none presentation and shared router)
        if let lastChild = children.last,
           shouldRecurseIntoChild(lastChild)
        {
            return lastChild.deepestVisibleCoordinator
        }

        return self
    }

    /// Find coordinator that is visibly presented/pushed on top of a container coordinator.
    ///
    /// **Purpose:**
    /// Distinguish between:
    /// - **Container children** (tabs/segments): Part of the container, not on top
    /// - **Presented/Pushed coordinators**: Visible on top of everything
    ///
    /// **Returns:** The coordinator on top, or `nil` if none exists
    private func findCoordinatorOnTopOfContainer(activeChild: Coordinator?) -> Coordinator? {
        // Get the last child (most recently added)
        guard let lastChild = children.last else { return nil }

        // If last child IS the active child → nothing on top
        guard lastChild !== activeChild else { return nil }

        // Last child must be a RouterCoordinator to be navigable
        guard let routerChild = lastChild as? RouterCoordinator else { return nil }

        // Check if this coordinator is actually visible on top
        if isCoordinatorVisibleOnTop(routerChild) {
            return lastChild
        }

        return nil
    }

    /// Determine if a coordinator is visibly on top of the screen.
    ///
    /// **Logic:**
    /// - **Modal/PanModal** → Always on top (has its own navigation controller)
    /// - **Push** → On top only if it uses the parent's router (same navigation stack)
    /// - **None** → Not visible on top
    ///
    /// **Why check router identity for push?**
    /// - Tab/Segment children have `.push` style but use their own router
    /// - Regular pushed coordinators share parent's router
    private func isCoordinatorVisibleOnTop(_ coordinator: RouterCoordinator) -> Bool {
        switch coordinator.presentationStyle {
        case .present, .panModel:
            // Modal presentations are always on top (new navigation hierarchy)
            return true

        case .push:
            // Pushed coordinator is on top if it shares parent's router
            guard let parentRouter = (self as? RouterCoordinator)?.router else {
                return false
            }
            // Identity comparison: same router instance means same navigation stack
            return coordinator.router === parentRouter

        case .none:
            // Embedded coordinators are not on top
            return false
        }
    }

    /// Determine if should recurse into a child coordinator.
    ///
    /// **Purpose:**
    /// Skip embedded components (plugins/widgets) that are not navigation destinations.
    ///
    /// **Logic:**
    /// - Non-router children → Always recurse (they are navigable)
    /// - Router children with `.none` presentation and shared router → Skip (embedded components)
    /// - All other router children → Recurse (navigation destinations)
    ///
    /// **Example:**
    /// ```
    /// MHHomeCoordinator [push, router: R1]
    ///   ├─ MHHomeHeaderPluginCoordinator [none, router: R1] ← Skip (embedded)
    ///   ├─ MHHomeReportPluginCoordinator [none, router: R1] ← Skip (embedded)
    ///   └─ DetailCoordinator [push, router: R1] ← Recurse (navigation destination)
    /// ```
    private func shouldRecurseIntoChild(_ child: Coordinator) -> Bool {
        guard let routerChild = child as? RouterCoordinator else {
            // Non-router children are always navigable
            return true
        }

        // Skip embedded children (.none with shared router)
        // These are UI components (plugins/widgets), not navigation destinations
        if routerChild.presentationStyle == .none,
           let selfRouter = (self as? RouterCoordinator)?.router,
           routerChild.router === selfRouter
        {
            return false
        }

        // All other children are navigation destinations
        return true
    }

    /// Returns the deepest visible `RouterCoordinator` in the coordinator tree.
    ///
    /// **Logic:**
    /// 1. Get the deepest visible coordinator using `deepestVisibleCoordinator`
    /// 2. If it's a `RouterCoordinator`, return it
    /// 3. If not, traverse up the parent chain until finding a `RouterCoordinator`
    /// 4. Return `nil` if no `RouterCoordinator` is found
    ///
    /// **Use Case:**
    /// Used for deep linking to get the router coordinator that's currently displayed on screen,
    /// allowing navigation operations (push/present) to be performed from the correct router.
    public var deepestVisibleRouterCoordinator: RouterCoordinator? {
        var current: Coordinator? = deepestVisibleCoordinator

        // Traverse up the coordinator tree to find a RouterCoordinator
        while let coor = current {
            if let routerCoor = coor as? RouterCoordinator {
                return routerCoor
            }
            current = coor.parentCoordinator
        }

        return nil
    }
}
