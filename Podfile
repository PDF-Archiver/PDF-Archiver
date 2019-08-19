# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'PDFArchiver' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for PDFArchiver
  pod 'TagListView', '~> 1.3'
  pod 'WSTagsField', '~> 5.0'
  pod 'Sentry', '~> 4.3'
  pod 'WeScan', :git => 'https://github.com/PDF-Archiver/WeScan', :branch => 'master'
  pod 'SwiftyTesseract', :git => 'https://github.com/PDF-Archiver/SwiftyTesseract', :branch => 'master'
  pod 'SwiftyStoreKit', '~> 0.15'
  pod 'paper-onboarding', '~> 6.1'
  pod 'SkyFloatingLabelTextField', '~> 3.7'

end

plugin 'cocoapods-keys', {
  :project => "PDFArchiver",
  :keys => [
    "AppstoreConnectSharedSecret",
    "SentryDSN"
  ]}
