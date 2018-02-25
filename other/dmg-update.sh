#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

cd "$SCRIPTPATH/.."

git stash
git checkout master

# xcodebuild
mkdir -p "$SCRIPTPATH/build"
xcodebuild archive -scheme "PDF Archiver" -archivePath "$SCRIPTPATH/build/PDF Archiver.xcarchive"
xcodebuild -exportArchive -archivePath "$SCRIPTPATH/build/PDF Archiver.xcarchive" -exportOptionsPlist other/export-options.plist -exportPath "$SCRIPTPATH/build/"

dmgbuild -s "$SCRIPTPATH/dmg-settings.py" "PDF Archiver" "PDFArchiver.dmg"

scp PDFArchiver.dmg freenas:/mnt/zpool/configs/NGINX-files/app/

rm -rf "$SCRIPTPATH/build"
rm "$SCRIPTPATH/../PDFArchiver.dmg"

git checkout develop
git stash apply
