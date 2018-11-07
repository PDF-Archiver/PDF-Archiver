fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew cask install fastlane`

# Available Actions
### createNewScreenshots
```
fastlane createNewScreenshots
```
Generate new localized screenshots
### sentry
```
fastlane sentry
```
Upload binary to Sentry.io
### beta
```
fastlane beta
```
Build Beta-Version & Upload it to TestFlight.
### metadata
```
fastlane metadata
```
Update metadata to App Store Connect.

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
