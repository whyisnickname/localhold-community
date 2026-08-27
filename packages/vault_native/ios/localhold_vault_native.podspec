# SPDX-License-Identifier: MPL-2.0
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint localhold_vault_native.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'localhold_vault_native'
  s.version          = '0.1.0'
  s.summary          = 'Typed native vault security boundary for Localhold.'
  s.description      = <<-DESC
Native-owned Localhold vault key hierarchy and authenticated encryption.
                       DESC
  s.homepage         = 'https://github.com/whyisnickname/localhold-community'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Localhold Community'
  s.source           = { :path => '.' }
  s.source_files = 'localhold_key_bridge/Sources/localhold_key_bridge/**/*.swift'
  s.vendored_frameworks = 'Frameworks/Clibsodium.xcframework'
  s.resource_bundles = {
    'localhold_key_bridge_recovery' => [
      'localhold_key_bridge/Sources/localhold_key_bridge/Resources/bip39_english.txt',
      'localhold_key_bridge/Sources/localhold_key_bridge/PrivacyInfo.xcprivacy'
    ]
  }
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '6.0'
end
