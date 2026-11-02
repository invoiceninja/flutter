#!/usr/bin/env ruby
# frozen_string_literal: true

# Pin each signed macOS target's Mac App Store provisioning profile in its
# Release configuration — ON THE CI RUNNER ONLY, right before the archive
# (.github/workflows/appstore-macos.yml). The tracked project stays on
# Automatic signing for local development and is never committed back.
#
# The macOS twin of tools/ci_ios_target_profiles.rb, for the same reason: a
# PROVISIONING_PROFILE_SPECIFIER on the xcodebuild command line applies to
# EVERY target, and since the home-screen widgets (docs/home-screen-widgets.md)
# the Runner embeds a second signed target with its own bundle id — the global
# override made the extension sign with the app's profile and the archive fail.
#
# Profile NAMES, matching macos/ExportOptions.plist's provisioningProfiles.
require 'xcodeproj'

PROFILES = {
  'Runner' => 'Invoice Ninja macOS App Store',
  'HomeWidgets' => 'Invoice Ninja Home Widgets macOS App Store',
}.freeze

project = Xcodeproj::Project.open(File.expand_path('../macos/Runner.xcodeproj', __dir__))

PROFILES.each do |target_name, profile|
  target = project.targets.find { |t| t.name == target_name }
  abort "No #{target_name} target in macos/Runner.xcodeproj" unless target
  config = target.build_configurations.find { |c| c.name == 'Release' }
  abort "No Release configuration on #{target_name}" unless config
  config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  # The conditional key the targets carry (an unconditional one would rank
  # below it). The workflow also passes it on the command line.
  config.build_settings['CODE_SIGN_IDENTITY[sdk=macosx*]'] = 'Apple Distribution'
  config.build_settings['DEVELOPMENT_TEAM'] = 'NPC44Y2C98'
  config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = profile
  puts "#{target_name} (Release): #{profile}"
end

project.save
