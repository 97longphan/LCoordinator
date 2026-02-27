//
//  DeeplinkManager.swift
//  TCB-SoftPOS
//
//  Created by LONGPHAN on 22/8/25.
//

import Foundation

public protocol DeeplinkHandlerDelegate: AnyObject {
    func handleDeeplink(_ payload: DeeplinkPayload)
}

public final class DeeplinkManager {

    private let plugins: [DeepLinkPlugin]
    private weak var delegate: DeeplinkHandlerDelegate?

    public init(plugins: [DeepLinkPlugin]) {
        self.plugins = plugins
    }

    public func setDelegate(_ delegate: DeeplinkHandlerDelegate) {
        self.delegate = delegate
    }

    public func handle(url: URL, context: [String: Any] = [:]) {

        let component = DeeplinkPluginComponent(url: url, context: context)

        guard let plugin = plugins.first(where: { $0.isApplicable(component: component) }) else {
            print("❌ No matching deeplink for: \(url.absoluteString)")
            return
        }

        print("✅ Matched deeplink plugin: \(type(of: plugin))")
        delegate?.handleDeeplink((component, plugin))
    }
}
