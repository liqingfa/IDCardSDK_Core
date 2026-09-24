Pod::Spec.new do |s|
  s.name             = 'IDCardSDK_Core'
  s.version          = '1.0.0'
  s.summary          = 'Offline mainland China resident ID card recognition for iOS.'
  s.description      = 'Recognizes ID card images locally using Apple Vision, extracts front and back fields and the portrait, and validates the 18-digit ID number.'
  s.homepage         = 'https://github.com/liqingfa/IDCardSDK_Core'
  s.license          = { :type => 'Proprietary' }
  s.author           = 'IDCardSDK contributors'
  s.source           = { :git => 'https://github.com/liqingfa/IDCardSDK_Core.git', :branch => 'main' }
  s.ios.deployment_target = '15.0'
  s.swift_version    = '5.9'
  s.source_files     = 'Sources/IDCardSDK_Core/**/*.swift'
  s.frameworks       = 'UIKit', 'Vision', 'CoreImage', 'CoreGraphics', 'CoreVideo'
end
