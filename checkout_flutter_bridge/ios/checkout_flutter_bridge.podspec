#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint checkout_flutter_bridge.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'checkout_flutter_bridge'
  s.version          = '0.1.0'
  s.summary          = 'A Flutter plugin for integrating Checkout.com payment gateway.'
  s.description      = <<-DESC
A Flutter plugin for integrating Checkout.com payment gateway with support for card tokenization and Apple Pay.
                       DESC
  s.homepage         = 'https://github.com/muhammadrashadomar/checkout_flutter_bridge'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Muhammad Rashad Omar' => 'your.email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '6.0'
  
  # PassKit framework for Apple Pay
  s.frameworks = 'PassKit'
  
  # Note: Checkout.com iOS SDK should be added via Swift Package Manager
  # Add https://github.com/checkout/checkout-ios-components to your Xcode project
end
