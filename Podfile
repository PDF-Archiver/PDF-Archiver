# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'PDFArchiver' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for PDFArchiver
  pod 'Sentry', '~> 4.3'
  pod 'paper-onboarding', '~> 6.1'

end

plugin 'cocoapods-keys', {
  :project => "PDFArchiver",
  :keys => [
    "AppstoreConnectSharedSecret",
    "SentryDSN",
    "LogUser",
    "LogPassword"
  ]}
