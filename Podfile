# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'PDFArchiver' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for PDFArchiver
  pod 'TagListView', '~> 1.3'
  pod 'WSTagsField', '~> 4.1'
  pod 'Sentry', '~> 4.2'
  pod 'WeScan', :git => 'https://github.com/PDF-Archiver/WeScan', :branch => 'master'
  pod 'SwiftyTesseract', '~> 2.2'
  pod 'SwiftyStoreKit', '~> 0.14.2'
  pod 'paper-onboarding', '~> 6.1.3'

  target 'PDFArchiverUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

plugin 'cocoapods-keys', {
  :project => "PDFArchiver",
  :keys => [
    "AppstoreConnectSharedSecret",
    "SentryDSN"
  ]}
