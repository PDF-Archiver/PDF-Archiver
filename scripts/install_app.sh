#!/bin/bash

REPO_FOLDER="$(git rev-parse --show-toplevel)"

# build OpenSSL
bash "$REPO_FOLDER/scripts/build_openssl.sh"

# build OpenSSL
bash "$REPO_FOLDER/scripts/build_app.sh"

# copy the app
cp -r "$REPO_FOLDER/build/PDFArchiver.app" "$HOME/Applications/"
