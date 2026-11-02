#!/usr/bin/env ruby
# frozen_string_literal: true

# Adds the macOS home-screen widget extension (`HomeWidgets`) to
# macos/Runner.xcodeproj — docs/home-screen-widgets.md. Idempotent. The iOS
# twin is tools/add_home_widgets_target.rb; the Swift sources are the iOS
# extension's (ios/HomeWidgets/), referenced from here, one copy.
#
#   ruby tools/add_home_widgets_macos_target.rb
#
#   * an app-extension target `HomeWidgets` (macOS 14), bundle id
#     com.invoiceninja.admin.HomeWidgets, sandboxed, in the team-prefixed App
#     Group the Runner now also claims;
#   * every Swift file in ios/HomeWidgets/ compiled into it, and the three the
#     app needs too (plus ios/Runner/HomeWidgetsBridge.swift, shared) into the
#     Runner — NOT StopTimerIntent.swift, which would let a Stop run in the
#     app's process;
#   * the .appex embedded in the Runner's Contents/PlugIns.
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(ROOT, 'macos/Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'No Runner target'

TARGET = 'HomeWidgets'
SHARED_WITH_RUNNER = %w[WidgetFiles.swift WidgetSnapshot.swift WidgetIntents.swift].freeze

# The macOS-only files (Info.plist, entitlements, xcconfig) live in
# macos/HomeWidgets; the sources in ios/HomeWidgets.
group = project.main_group.children.find { |g| g.display_name == TARGET } ||
        project.main_group.new_group(TARGET, TARGET)
shared = group.children.find { |g| g.display_name == 'Shared' } ||
         group.new_group('Shared', '../../ios/HomeWidgets')

def file_ref(group, name)
  group.files.find { |f| f.path == name } || group.new_reference(name)
end

ios_dir = File.join(ROOT, 'ios', TARGET)
swift_files = Dir.children(ios_dir).select { |f| f.end_with?('.swift') }.sort
refs = swift_files.to_h { |f| [f, file_ref(shared, f)] }
catalog = file_ref(shared, 'Localizable.xcstrings')
xcconfig = file_ref(group, "#{TARGET}.xcconfig")
%w[Info.plist HomeWidgets.entitlements].each { |f| file_ref(group, f) }

target = project.targets.find { |t| t.name == TARGET } ||
         project.new_target(:app_extension, TARGET, :osx, '14.0', project.products_group, :swift)

target.build_configurations.each do |config|
  config.base_configuration_reference = xcconfig
  s = config.build_settings
  s['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
  s['CODE_SIGN_ENTITLEMENTS'] = "#{TARGET}/#{TARGET}.entitlements"
  s['CODE_SIGN_STYLE'] = 'Automatic'
  # As the Runner: an embedded binary must be signed with the same
  # certificate, and the project-level default is ad hoc ("-").
  s['CODE_SIGN_IDENTITY[sdk=macosx*]'] = 'Apple Development'
  s['PROVISIONING_PROFILE_SPECIFIER'] = ''
  s['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
  s['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
  s['DEVELOPMENT_TEAM'] = 'NPC44Y2C98'
  s['ENABLE_HARDENED_RUNTIME'] = 'YES'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['INFOPLIST_FILE'] = "#{TARGET}/Info.plist"
  s['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/../Frameworks',
                                  '@executable_path/../../../../Frameworks']
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.invoiceninja.admin.HomeWidgets'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['SDKROOT'] = 'macosx'
  s['SKIP_INSTALL'] = 'YES'
  s['SWIFT_VERSION'] = '5.0'
end

def add_source(target, ref)
  return if target.source_build_phase.files_references.include?(ref)

  target.source_build_phase.add_file_reference(ref)
end

def add_resource(target, ref)
  return if target.resources_build_phase.files_references.include?(ref)

  target.resources_build_phase.add_file_reference(ref)
end

refs.each_value { |ref| add_source(target, ref) }
add_resource(target, catalog)
SHARED_WITH_RUNNER.each { |f| add_source(runner, refs.fetch(f)) }

ios_runner = group.children.find { |g| g.display_name == 'SharedRunner' } ||
             group.new_group('SharedRunner', '../../ios/Runner')
add_source(runner, file_ref(ios_runner, 'HomeWidgetsBridge.swift'))

embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed App Extensions' } ||
        runner.new_copy_files_build_phase('Embed App Extensions').tap do |p|
          p.symbol_dst_subfolder_spec = :plug_ins
        end
unless embed.files_references.include?(target.product_reference)
  build_file = embed.add_file_reference(target.product_reference)
  build_file.settings = { 'ATTRIBUTES' => %w[CodeSignOnCopy RemoveHeadersOnCopy] }
end
runner.add_dependency(target) unless runner.dependencies.any? { |d| d.target == target }

# The Foundation reference `new_target` pins to one SDK: dead elsewhere.
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

APPLE_REGIONS = %w[
  en Base af ar bg ca cs da de el es es-419 et fa fi fr fr-CA fr-CH he hr hu id
  it ja km lo lt lv mk nb nl pl pt-BR pt-PT ro ru sk sl sq sr-Latn sv th tr vi
  zh-Hans zh-Hant
].freeze
project.root_object.known_regions = (project.root_object.known_regions | APPLE_REGIONS)

project.save
puts "#{TARGET} (macOS): #{swift_files.size} Swift files; #{SHARED_WITH_RUNNER.size} shared with Runner"
