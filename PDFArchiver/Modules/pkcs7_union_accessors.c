//
//  pkcs7_union_accessors.c
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.06.18.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
//
//  ORIGINAL FROM:
//  SwiftyReceiptValidatorDemo
//
//  Created by Andrew Bancroft on 10/26/17.
//  Copyright © 2017 Andrew Bancroft. All rights reserved.
//

#include "pkcs7_union_accessors.h"

inline char *pkcs7_d_char(PKCS7 *ptr) {
    return ptr->d.ptr;
}

inline ASN1_OCTET_STRING *pkcs7_d_data(PKCS7 *ptr) {
    return ptr->d.data;
}

inline PKCS7_SIGNED *pkcs7_d_sign(PKCS7 *ptr) {
    return ptr->d.sign;
}

inline PKCS7_ENVELOPE *pkcs7_d_enveloped(PKCS7 *ptr) {
    return ptr->d.enveloped;
}

inline PKCS7_SIGN_ENVELOPE *pkcs7_d_signed_and_enveloped(PKCS7 *ptr) {
    return ptr->d.signed_and_enveloped;
}

inline PKCS7_DIGEST *pkcs7_d_digest(PKCS7 *ptr) {
    return ptr->d.digest;
}

inline PKCS7_ENCRYPT *pkcs7_d_encrypted(PKCS7 *ptr) {
    return ptr->d.encrypted;
}

inline ASN1_TYPE *pkcs7_d_other(PKCS7 *ptr) {
    return ptr->d.other;
}
