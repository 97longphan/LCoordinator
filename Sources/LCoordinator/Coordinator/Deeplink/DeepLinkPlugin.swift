//
//  DeepLinkPlugin.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation

public typealias DeeplinkPayload = (
    component: DeeplinkPluginComponent,
    plugin: DeepLinkPlugin
)

public protocol DeepLinkPlugin {
    var path: String { get }
    func isApplicable(component: DeeplinkPluginComponent) -> Bool
    func buildCoordinator(
        component: DeeplinkPluginComponent,
        router: RouterProtocol
    ) -> Coordinator?
    func shouldPreventDuplicate(whenExists coordinatorType: Coordinator.Type) -> Bool
}

public extension DeepLinkPlugin {
    func isApplicable(component: DeeplinkPluginComponent) -> Bool {
        let host = component.url.host?.lowercased()
        let cleanPath = component.url
            .path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        return host == path.lowercased() || cleanPath == path.lowercased()
    }

    func shouldPreventDuplicate(whenExists coordinatorType: Coordinator.Type) -> Bool {
        return false
    }
}

public struct DeeplinkPluginComponent {
    public let url: URL
    public let context: [String: Any]

    public init(url: URL, context: [String: Any] = [:]) {
        self.url = url
        self.context = context
    }
}

extension URL {
    public var queryParameters: [String: String]? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [:]) { $0[$1.name] = $1.value }
    }
}
