#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

cd "$SCRIPTPATH/.."

xcodebuild
dmgbuild -s "$SCRIPTPATH/settings.py" "PDF Archiver" "PDFArchiver.dmg"

scp PDFArchiver.dmg freenas:/mnt/zpool/configs/NGINX-files/app/

rm -rf "$SCRIPTPATH/../build"
rm "$SCRIPTPATH/../PDFArchiver.dmg"
