#!/usr/bin/env ruby
# frozen_string_literal: true

# Pin each signed iOS target's App Store provisioning profile in its Release
# configuration — ON THE CI RUNNER ONLY, right before the archive
# (.github/workflows/appstore-ios.yml). The tracked project stays on Automatic
# signing for local development and is never committed back.
#
# WHY NOT `xcodebuild … PROVISIONING_PROFILE_SPECIFIER=…`: a build setting on
# the xcodebuild command line applies to EVERY target. Since the Share Extension
# (invoiceninja/flutter#173) the Runner embeds a second signed target with its
# own bundle id, and a profile is bound to one bundle id — the global override
# made the extension sign with the app's profile and the archive fail.
#
# Uses the `xcodeproj` gem, which ships with CocoaPods (installed on the
# runner, and required by `flutter build ios` anyway).
#
# Profile NAMES, matching ios/ExportOptions.plist's provisioningProfiles; the
# profiles themselves are installed from secrets by the workflow.
require 'xcodeproj'

PROFILES = {
  'Runner' => 'Invoice Ninja Admin App Store',
  'ShareExtension' => 'Invoice Ninja Share Extension App Store',
}.freeze

project = Xcodeproj::Project.open(File.expand_path('../ios/Runner.xcodeproj', __dir__))

PROFILES.each do |target_name, profile|
  target = project.targets.find { |t| t.name == target_name }
  abort "No #{target_name} target in ios/Runner.xcodeproj" unless target
  config = target.build_configurations.find { |c| c.name == 'Release' }
  abort "No Release configuration on #{target_name}" unless config
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = profile
  puts "#{target_name} (Release): #{profile}"
end

project.save
