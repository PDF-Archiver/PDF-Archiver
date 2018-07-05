#!/bin/bash

# build OpenSSL
bash scripts/build_openssl.sh

# build the app
xcodebuild clean
xcodebuild build CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# copy the app
cp -r "build/Release/PDFArchiver.app" "$HOME/Applications/"
