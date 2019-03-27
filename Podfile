# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'PDFArchiveViewer' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for PDFArchiveViewer
  pod 'TagListView', '~> 1.3'
  pod 'Sentry', '~> 4.2'
  pod 'WeScan', '~> 1.0'
  pod 'SwiftyTesseract', :git => 'https://github.com/PDF-Archiver/SwiftyTesseract.git', :branch => 'master'
  pod 'SwiftyStoreKit', '~> 0.14.2'

  target 'PDFArchiveViewerUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

plugin 'cocoapods-keys', {
  :project => "PDFArchiveViewer",
  :keys => [
    "AppstoreConnectSharedSecret",
    "SentryDSN"
  ]}
