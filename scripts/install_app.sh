#!/bin/bash

REPO_FOLDER="$(git rev-parse --show-toplevel)"

# build OpenSSL
bash "$REPO_FOLDER/scripts/build_openssl.sh"

# build the app
xcodebuild clean
xcodebuild build -quiet -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# copy the app
cp -r "$REPO_FOLDER/build/Debug/PDFArchiver.app" "$HOME/Applications/"
