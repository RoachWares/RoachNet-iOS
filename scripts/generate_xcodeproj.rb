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
project.root_object.attributes['ORGANIZATIONNAME'] = 'AHG Records LLC'

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
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.ahgrecords.RoachNetCompanion'
  config.build_settings['INFOPLIST_FILE'] = 'RoachNetCompanion/Info.plist'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '0.1.2'
  config.build_settings['ENABLE_PREVIEWS'] = 'YES'
  config.build_settings['SWIFT_STRICT_CONCURRENCY'] = 'complete'
  config.build_settings['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
end

project.save
puts "Generated #{PROJECT_PATH}"
