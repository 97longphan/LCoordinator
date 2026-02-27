Pod::Spec.new do |s|
  s.name             = 'LCoordinator'
  s.version          = '1.0.0'
  s.summary          = 'Coordinator + Router + Deeplink SDK for iOS'
  s.description      = <<-DESC
    LCoordinator provides a clean Coordinator pattern implementation
    with Router, Deeplink, and PanModal (bottom sheet) support for iOS apps.
    Includes base classes for push/present/panModal navigation flows.
  DESC

  s.homepage         = 'https://gitlab.id.vin'
  s.license          = { :type => 'MIT' }
  s.author           = { 'LONGPHAN' => 'longphan@vinid.net' }
  s.platform         = :ios, '14.0'
  s.swift_version    = '5.9'

  # For local development: path-based. Switch to git source when publishing.
  s.source           = { :git => '', :tag => s.version.to_s }

  s.source_files     = 'Sources/LCoordinator/**/*.swift'

  s.frameworks       = 'UIKit', 'Foundation'
end
