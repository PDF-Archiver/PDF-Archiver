#!/bin/bash
# from: https://medium.com/@joncardasis/openssl-swift-everything-you-need-to-know-2a4f9f256462

OSX_DEPLOYMENT_VERSION="10.12"

OSX_SDK=$(xcrun --sdk macosx --show-sdk-path)
REPO_FOLDER="$(git rev-parse --show-toplevel)"
OPENSSL_FOLDER="$REPO_FOLDER/PDFArchiver/External/OpenSSL"

# Create openssl folder structure, hidden at first
OPENSSL_LIB_FOLDER="$OPENSSL_FOLDER/lib"
OPENSSL_INCLUDE_FOLDER="$OPENSSL_FOLDER/include"
mkdir "$OPENSSL_LIB_FOLDER" 2> /dev/null
mkdir "$OPENSSL_INCLUDE_FOLDER" 2> /dev/null

# skip building if libs already exist
if [ -e "$OPENSSL_LIB_FOLDER/libcrypto.a" ] && [ -e "$OPENSSL_LIB_FOLDER/libssl.a" ] ; then
    echo "all files exists, skipping build"
    exit 0
fi

# Build OpenSSL
cd "$OPENSSL_FOLDER/src"
make clean
./Configure darwin64-x86_64-cc
sed -ie "s!^CFLAG=!CFLAG=-isysroot ${OSX_SDK} -arch x86_64 -mmacosx-version-min=${OSX_DEPLOYMENT_VERSION} !" "Makefile"
echo "Building x86 64 static library..."
make install >> /dev/null 2>&1

cp "LICENSE" "$OPENSSL_FOLDER"
cp -r "include/" "$OPENSSL_INCLUDE_FOLDER"
cp "libcrypto.a" "$OPENSSL_LIB_FOLDER"
cp "libssl.a" "$OPENSSL_LIB_FOLDER"

echo "Finished OpenSSL generation script."
exit 0
