//
//  shim.h
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.06.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

#ifndef __OPENSSL_SHIM_H__
#define __OPENSSL_SHIM_H__

//#include <openssl/conf.h>
//#include <openssl/evp.h>
//#include <openssl/err.h>
//#include <openssl/bio.h>
//#include <openssl/ssl.h>
//#include <openssl/md4.h>
//#include <openssl/md5.h>
//#include <openssl/sha.h>
//#include <openssl/hmac.h>
//#include <openssl/rand.h>
//#include <openssl/ripemd.h>
//#include <openssl/pkcs12.h>
//#include <openssl/x509v3.h>
//#include <openssl/pkcs7_union_accessors.h>

#include "pkcs7_union_accessors.h"
#import <openssl/pkcs7.h>
#import <openssl/objects.h>
#import <openssl/sha.h>
#import <openssl/x509.h>

#endif
