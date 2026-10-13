#!/usr/bin/env ruby

require 'fileutils'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'RoachNetCompanion.xcodeproj')
TARGET_NAME = 'RoachNetCompanion'
APP_DIR = File.join(ROOT, 'RoachNetCompanion')

FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes['LastUpgradeCheck'] = '1640'
project.root_object.attributes['ORGANIZATIONNAME'] = 'RoachWares LLC'

main_group = project.main_group
app_group = main_group.new_group('RoachNetCompanion')
scripts_group = main_group.new_group('scripts')
scripts_group.new_file('scripts/generate_xcodeproj.rb')

target = project.new_target(:application, TARGET_NAME, :ios, '17.0')

support_files = []
resource_files = []
asset_catalog_path = 'RoachNetCompanion/Assets.xcassets'

Dir.glob(File.join(APP_DIR, '**', '*')).sort.each do |absolute_path|
  next if File.directory?(absolute_path)

  relative_path = absolute_path.sub("#{ROOT}/", '')
  next if relative_path.end_with?('.xcodeproj')
  next if relative_path.start_with?("#{asset_catalog_path}/")

  file_ref = app_group.new_file(relative_path)

  case File.extname(relative_path)
  when '.swift'
    support_files << file_ref
  when '.plist'
    next
  else
    resource_files << file_ref
  end
end

resource_files << app_group.new_file(asset_catalog_path)

target.add_file_references(support_files)
target.resources_build_phase.add_file_reference(resource_files[0], true) unless resource_files.empty?
resource_files.drop(1).each do |file_ref|
  target.resources_build_phase.add_file_reference(file_ref, true)
end

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = TARGET_NAME
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.roachwares.RoachNetCompanion'
  config.build_settings['INFOPLIST_FILE'] = 'RoachNetCompanion/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '8'
  config.build_settings['MARKETING_VERSION'] = '0.3.1'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  config.build_settings['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
end

# UI tests (XCUITest). They drive the app in demo mode (ROACHNET_DEMO_MODE=1), so they
# need no desktop; live pairing is covered by RoachNet's simulator pairing check.
UITEST_NAME = 'RoachNetCompanionUITests'
UITEST_DIR = File.join(ROOT, UITEST_NAME)
ui_group = main_group.new_group(UITEST_NAME)
ui_target = project.new_target(:ui_test_bundle, UITEST_NAME, :ios, '17.0')
ui_files = Dir.glob(File.join(UITEST_DIR, '**', '*.swift')).sort.map do |absolute_path|
  ui_group.new_file(absolute_path.sub("#{ROOT}/", ''))
end
ui_target.add_file_references(ui_files)
ui_target.add_dependency(target)
ui_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.roachwares.RoachNetCompanionUITests'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['TEST_TARGET_NAME'] = TARGET_NAME
end

project.predictabilize_uuids
project.save

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(ui_target)
scheme.set_launch_target(target)
scheme.save_as(PROJECT_PATH, TARGET_NAME, true)
puts "Generated #{PROJECT_PATH}"
