source 'https://github.com/CocoaPods/Specs.git'

target 'PandaPlay' do
  use_frameworks!
  platform :ios, '15.0'
  pod 'MobileVLCKit', '~>3.3.0'
end

target 'PandaPlay-tvOS' do
  use_frameworks!
  platform :tvos, '15.0'
  pod 'TVVLCKit', '~>3.3.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if target.name.include?('Pods-PandaPlay-tvOS')
        config.build_settings['TVOS_DEPLOYMENT_TARGET'] = '15.0'
      else
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end
end
