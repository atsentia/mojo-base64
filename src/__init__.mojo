"""
Mojo Base64 Library

Pure Mojo Base64 encoding/decoding.
Supports standard (RFC 4648) and URL-safe variants.

Example:
    from mojo_base64 import encode, decode, urlsafe_encode, urlsafe_decode

    # Standard Base64
    var encoded = encode_string("Hello World!")  # "SGVsbG8gV29ybGQh"
    var decoded = decode_to_string(encoded)       # "Hello World!"

    # URL-safe Base64 (no padding)
    var url_encoded = urlsafe_encode_string("Hello World!")
"""

from .base64 import (
    encode,
    encode_string,
    decode,
    decode_to_string,
    urlsafe_encode,
    urlsafe_encode_string,
    urlsafe_decode,
    urlsafe_decode_to_string,
    Base64Encoder,
    Base64Decoder,
)
