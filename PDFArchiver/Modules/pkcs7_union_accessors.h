//
//  pkcs7_union_accessors.h
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.06.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

#ifndef pkcs7_union_accessors_h
#define pkcs7_union_accessors_h

#include <openssl/pkcs7.h>

char *pkcs7_d_char(PKCS7 *ptr);
ASN1_OCTET_STRING *pkcs7_d_data(PKCS7 *ptr);
PKCS7_SIGNED *pkcs7_d_sign(PKCS7 *ptr);
PKCS7_ENVELOPE *pkcs7_d_enveloped(PKCS7 *ptr);
PKCS7_SIGN_ENVELOPE *pkcs7_d_signed_and_enveloped(PKCS7 *ptr);
PKCS7_DIGEST *pkcs7_d_digest(PKCS7 *ptr);
PKCS7_ENCRYPT *pkcs7_d_encrypted(PKCS7 *ptr);
ASN1_TYPE *pkcs7_d_other(PKCS7 *ptr);

#endif /* pkcs7_union_accessors_h */
