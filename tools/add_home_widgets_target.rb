#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the home-screen widget extension (`HomeWidgets`) to ios/Runner.xcodeproj
# — docs/home-screen-widgets.md. Idempotent: run it again and it changes
# nothing. Kept so the project change can be reviewed, and redone if the
# project is ever regenerated.
#
#   ruby tools/add_home_widgets_target.rb
#
# What it does, mirroring the Share Extension (invoiceninja/flutter#173):
#   * an app-extension target `HomeWidgets` (iOS 17 — AppIntentConfiguration,
#     interactive buttons), bundle id com.invoiceninja.admin.HomeWidgets, its
#     version from Flutter/Generated.xcconfig (HomeWidgets.xcconfig);
#   * every Swift file in ios/HomeWidgets/ compiled into it — and of those,
#     NOT StopTimerIntent.swift into the Runner (see that file);
#   * the three files the app needs too (the paths, the snapshot model, the
#     intents its `installed()` reads configurations back with) compiled into
#     Runner, with Runner/HomeWidgetsBridge.swift;
#   * the .appex added to Runner's "Embed Foundation Extensions" phase — which
#     already sits before "Thin Binary", or Xcode reports a dependency cycle
#     (share_target_wiring_test pins that order).
#
# Uses the `xcodeproj` gem, which ships with CocoaPods.
require 'xcodeproj'

ROOT = File.expand_path('../ios', __dir__)
project = Xcodeproj::Project.open(File.join(ROOT, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'No Runner target'

TARGET = 'HomeWidgets'
SHARED_WITH_RUNNER = %w[WidgetFiles.swift WidgetSnapshot.swift WidgetIntents.swift].freeze

group = project.main_group.children.find { |g| g.display_name == TARGET } ||
        project.main_group.new_group(TARGET, TARGET)

def file_ref(group, name)
  group.files.find { |f| f.path == name } || group.new_reference(name)
end

swift_files = Dir.children(File.join(ROOT, TARGET)).select { |f| f.end_with?('.swift') }.sort
refs = swift_files.to_h { |f| [f, file_ref(group, f)] }
xcconfig = file_ref(group, "#{TARGET}.xcconfig")
%w[Info.plist HomeWidgets.entitlements].each { |f| file_ref(group, f) }

target = project.targets.find { |t| t.name == TARGET }
unless target
  target = project.new_target(:app_extension, TARGET, :ios, '17.0', project.products_group, :swift)
end

target.build_configurations.each do |config|
  config.base_configuration_reference = xcconfig
  s = config.build_settings
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['CLANG_ENABLE_OBJC_WEAK'] = 'NO'
  s['CODE_SIGN_ENTITLEMENTS'] = "#{TARGET}/#{TARGET}.entitlements"
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  s['DEVELOPMENT_TEAM'] = 'NPC44Y2C98'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['INFOPLIST_FILE'] = "#{TARGET}/Info.plist"
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks',
                                  '@executable_path/../../Frameworks']
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.invoiceninja.admin.HomeWidgets'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['SDKROOT'] = 'iphoneos'
  s['SKIP_INSTALL'] = 'YES'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['VALIDATE_PRODUCT'] = 'YES' unless config.name == 'Debug'
end

def add_source(target, ref)
  return if target.source_build_phase.files_references.include?(ref)

  target.source_build_phase.add_file_reference(ref)
end

refs.each_value { |ref| add_source(target, ref) }
SHARED_WITH_RUNNER.each { |f| add_source(runner, refs.fetch(f)) }

runner_group = project.main_group.children.find { |g| g.display_name == 'Runner' }
%w[HomeWidgetsBridge.swift AppShortcuts.swift].each do |name|
  add_source(runner, file_ref(runner_group, name))
end

embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' } or
  abort 'No "Embed Foundation Extensions" phase on Runner'
unless embed.files_references.include?(target.product_reference)
  build_file = embed.add_file_reference(target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
end

runner.add_dependency(target) unless runner.dependencies.any? { |d| d.target == target }

# String Catalogs: the text the OS shows for the widgets (gallery, Edit Widget,
# controls) and for the app's quick actions and Siri phrases. Xcode compiles
# each into per-language .lproj files; the languages are the catalog's.
def add_resource(target, ref)
  return if target.resources_build_phase.files_references.include?(ref)

  target.resources_build_phase.add_file_reference(ref)
end

add_resource(target, file_ref(group, 'Localizable.xcstrings'))
%w[Localizable.xcstrings InfoPlist.xcstrings].each do |name|
  add_resource(runner, file_ref(runner_group, name))
end

# Siri phrases: AppShortcuts.strings per .lproj, NOT a String Catalog — Xcode
# accepts an AppShortcuts catalog only for an iOS 17 deployment target, and the
# app's is 15. Generated from the translations; one variant group.
stale = runner_group.files.find { |f| f.path == 'AppShortcuts.xcstrings' }
if stale
  stale.build_files.each { |bf| bf.remove_from_project }
  stale.remove_from_project
end
phrases = runner_group.children.find { |g| g.display_name == 'AppShortcuts.strings' } ||
          runner_group.new_variant_group('AppShortcuts.strings')
Dir.glob(File.join(ROOT, 'Runner', '*.lproj', 'AppShortcuts.strings')).sort.each do |path|
  region = File.basename(File.dirname(path), '.lproj')
  rel = "#{region}.lproj/AppShortcuts.strings"
  next if phrases.files.any? { |f| f.path == rel }

  ref = phrases.new_reference(rel)
  ref.name = region
end
add_resource(runner, phrases)

# The app's languages (kSupportedLocales), as Apple names them — Xcode keeps a
# catalog's translations only for regions the project knows.
APPLE_REGIONS = %w[
  en Base af ar bg ca cs da de el es es-419 et fa fi fr fr-CA fr-CH he hr hu id
  it ja km lo lt lv mk nb nl pl pt-BR pt-PT ro ru sk sl sq sr-Latn sv th tr vi
  zh-Hans zh-Hant
].freeze
project.root_object.known_regions = (project.root_object.known_regions | APPLE_REGIONS)

# `new_target` links Foundation through a file reference pinned to the SDK the
# gem knows (`iPhoneOS18.0.sdk`), dead on any other Xcode. Swift links it
# anyway (`import Foundation`), so the reference is only noise: remove it.
target.frameworks_build_phase.files.dup.each do |build_file|
  ref = build_file.file_ref
  next unless ref && ref.path.to_s.match?(%r{(Foundation|Cocoa)\.framework\z})

  target.frameworks_build_phase.remove_build_file(build_file)
  ref.remove_from_project if ref.build_files.empty?
end
# …and the platform group it sat in, left empty.
project.frameworks_group.groups.dup.each do |g|
  g.remove_from_project if g.children.empty?
end

project.save
puts "#{TARGET}: #{swift_files.size} Swift files; #{SHARED_WITH_RUNNER.size} shared with Runner"
