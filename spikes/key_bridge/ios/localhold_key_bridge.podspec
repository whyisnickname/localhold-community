# SPDX-License-Identifier: MPL-2.0
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint localhold_key_bridge.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'localhold_key_bridge'
  s.version          = '0.0.0-spike.1'
  s.summary          = 'Typed native key bridge spike for Localhold.'
  s.description      = <<-DESC
Fail-closed Stage 2 contract spike. No production cryptography is included.
                       DESC
  s.homepage         = 'https://github.com/whyisnickname/localhold-community'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'whyisnickname'
  s.source           = { :path => '.' }
  s.source_files = 'localhold_key_bridge/Sources/localhold_key_bridge/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'localhold_key_bridge_privacy' => ['localhold_key_bridge/Sources/localhold_key_bridge/PrivacyInfo.xcprivacy']}
end
