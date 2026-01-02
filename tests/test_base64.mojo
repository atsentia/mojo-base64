"""
Base64 Tests
"""

from mojo_base64 import (
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


fn test_encode_basic() raises:
    """Test basic encoding."""
    # Test vector from RFC 4648
    var result = encode_string("Hello World!")
    if result != "SGVsbG8gV29ybGQh":
        raise Error("Basic encoding failed: " + result)

    print("✓ Basic encoding works")


fn test_encode_empty() raises:
    """Test empty input encoding."""
    var result = encode_string("")
    if result != "":
        raise Error("Empty encoding failed: " + result)

    print("✓ Empty encoding works")


fn test_encode_padding() raises:
    """Test padding cases."""
    # No padding needed (3 bytes -> 4 chars)
    var r1 = encode_string("abc")
    if r1 != "YWJj":
        raise Error("No padding case failed: " + r1)

    # One padding char (2 bytes -> 3 chars + 1 pad)
    var r2 = encode_string("ab")
    if r2 != "YWI=":
        raise Error("One padding case failed: " + r2)

    # Two padding chars (1 byte -> 2 chars + 2 pads)
    var r3 = encode_string("a")
    if r3 != "YQ==":
        raise Error("Two padding case failed: " + r3)

    print("✓ Padding works correctly")


fn test_decode_basic() raises:
    """Test basic decoding."""
    var result = decode_to_string("SGVsbG8gV29ybGQh")
    if result != "Hello World!":
        raise Error("Basic decoding failed: " + result)

    print("✓ Basic decoding works")


fn test_decode_padding() raises:
    """Test decoding with padding."""
    var r1 = decode_to_string("YWJj")
    if r1 != "abc":
        raise Error("No padding decode failed: " + r1)

    var r2 = decode_to_string("YWI=")
    if r2 != "ab":
        raise Error("One padding decode failed: " + r2)

    var r3 = decode_to_string("YQ==")
    if r3 != "a":
        raise Error("Two padding decode failed: " + r3)

    print("✓ Decoding with padding works")


fn test_roundtrip() raises:
    """Test encode/decode roundtrip."""
    var test_strings = List[String]()
    test_strings.append("Hello")
    test_strings.append("Hello World!")
    test_strings.append("The quick brown fox jumps over the lazy dog")
    test_strings.append("a")
    test_strings.append("ab")
    test_strings.append("abc")
    test_strings.append("0123456789")

    for i in range(len(test_strings)):
        var original = test_strings[i]
        var encoded = encode_string(original)
        var decoded = decode_to_string(encoded)
        if decoded != original:
            raise Error("Roundtrip failed for: " + original)

    print("✓ Encode/decode roundtrip works")


fn test_urlsafe_encode() raises:
    """Test URL-safe encoding."""
    # Create bytes that would produce + and / in standard encoding
    # 0xFB, 0xFF -> standard: +/8= url-safe: -_8
    var data = List[UInt8]()
    data.append(0xFB)
    data.append(0xFF)

    var standard = encode(data)
    var urlsafe = urlsafe_encode(data)

    # URL-safe should not have + or /
    for i in range(len(urlsafe)):
        if urlsafe[i] == "+" or urlsafe[i] == "/":
            raise Error("URL-safe contains forbidden characters: " + urlsafe)

    # URL-safe should not have padding
    if urlsafe.endswith("="):
        raise Error("URL-safe should not have padding: " + urlsafe)

    print("✓ URL-safe encoding works")


fn test_urlsafe_decode() raises:
    """Test URL-safe decoding."""
    var encoded = urlsafe_encode_string("Hello World!")
    var decoded = urlsafe_decode_to_string(encoded)

    if decoded != "Hello World!":
        raise Error("URL-safe roundtrip failed: " + decoded)

    print("✓ URL-safe decoding works")


fn test_streaming_encoder() raises:
    """Test streaming encoder."""
    var encoder = Base64Encoder()

    # Add data in chunks
    var chunk1 = List[UInt8]()
    chunk1.append(72)  # H
    chunk1.append(101) # e
    chunk1.append(108) # l
    encoder.update(chunk1)

    var chunk2 = List[UInt8]()
    chunk2.append(108) # l
    chunk2.append(111) # o
    encoder.update(chunk2)

    var result = encoder.finalize()
    if result != "SGVsbG8=":
        raise Error("Streaming encoder failed: " + result)

    print("✓ Streaming encoder works")


fn test_streaming_decoder() raises:
    """Test streaming decoder."""
    var decoder = Base64Decoder()
    decoder.update("SGVs")
    decoder.update("bG8=")

    var result = decoder.finalize()
    var decoded = String()
    for i in range(len(result)):
        decoded += chr(Int(result[i]))

    if decoded != "Hello":
        raise Error("Streaming decoder failed: " + decoded)

    print("✓ Streaming decoder works")


fn test_binary_data() raises:
    """Test encoding/decoding binary data."""
    var data = List[UInt8]()
    for i in range(256):
        data.append(UInt8(i))

    var encoded = encode(data)
    var decoded = decode(encoded)

    if len(decoded) != 256:
        raise Error("Binary data length mismatch: " + str(len(decoded)))

    for i in range(256):
        if Int(decoded[i]) != i:
            raise Error("Binary data mismatch at position " + str(i))

    print("✓ Binary data roundtrip works")


fn test_simd_encoding() raises:
    """
    Test SIMD-optimized encoding with various input sizes.

    Tests inputs that exercise:
    - Full SIMD chunks (12+ bytes)
    - Scalar fallback (remaining 3-byte groups)
    - Tail handling (1 or 2 remaining bytes)
    """
    # Test case 1: Exactly 12 bytes (1 full SIMD chunk, no remainder)
    var data12 = List[UInt8]()
    for i in range(12):
        data12.append(UInt8(65 + i))  # A-L
    var enc12 = encode(data12)
    var dec12 = decode(enc12)
    if len(dec12) != 12:
        raise Error("SIMD 12-byte roundtrip length mismatch")
    for i in range(12):
        if Int(dec12[i]) != 65 + i:
            raise Error("SIMD 12-byte roundtrip data mismatch at " + str(i))

    # Test case 2: 24 bytes (2 full SIMD chunks)
    var data24 = List[UInt8]()
    for i in range(24):
        data24.append(UInt8(48 + (i % 10)))  # 0-9 repeated
    var enc24 = encode(data24)
    var dec24 = decode(enc24)
    if len(dec24) != 24:
        raise Error("SIMD 24-byte roundtrip length mismatch")
    for i in range(24):
        if Int(dec24[i]) != 48 + (i % 10):
            raise Error("SIMD 24-byte roundtrip data mismatch at " + str(i))

    # Test case 3: 13 bytes (1 SIMD chunk + 1 byte remainder with padding)
    var data13 = List[UInt8]()
    for i in range(13):
        data13.append(UInt8(97 + i))  # a-m
    var enc13 = encode(data13)
    if not enc13.endswith("=="):
        raise Error("SIMD 13-byte should end with == padding, got: " + enc13)
    var dec13 = decode(enc13)
    if len(dec13) != 13:
        raise Error("SIMD 13-byte roundtrip length mismatch")
    for i in range(13):
        if Int(dec13[i]) != 97 + i:
            raise Error("SIMD 13-byte roundtrip data mismatch at " + str(i))

    # Test case 4: 14 bytes (1 SIMD chunk + 2 bytes remainder with = padding)
    var data14 = List[UInt8]()
    for i in range(14):
        data14.append(UInt8(65 + i))  # A-N
    var enc14 = encode(data14)
    if not enc14.endswith("=") or enc14.endswith("=="):
        raise Error("SIMD 14-byte should end with single = padding, got: " + enc14)
    var dec14 = decode(enc14)
    if len(dec14) != 14:
        raise Error("SIMD 14-byte roundtrip length mismatch")
    for i in range(14):
        if Int(dec14[i]) != 65 + i:
            raise Error("SIMD 14-byte roundtrip data mismatch at " + str(i))

    # Test case 5: 15 bytes (1 SIMD chunk + 3 bytes, no padding needed)
    var data15 = List[UInt8]()
    for i in range(15):
        data15.append(UInt8(65 + i))  # A-O
    var enc15 = encode(data15)
    if enc15.endswith("="):
        raise Error("SIMD 15-byte should have no padding, got: " + enc15)
    var dec15 = decode(enc15)
    if len(dec15) != 15:
        raise Error("SIMD 15-byte roundtrip length mismatch")

    # Test case 6: Large input (100 bytes - multiple SIMD chunks + remainder)
    var data100 = List[UInt8]()
    for i in range(100):
        data100.append(UInt8(i % 256))
    var enc100 = encode(data100)
    var dec100 = decode(enc100)
    if len(dec100) != 100:
        raise Error("SIMD 100-byte roundtrip length mismatch: " + str(len(dec100)))
    for i in range(100):
        if Int(dec100[i]) != i % 256:
            raise Error("SIMD 100-byte roundtrip data mismatch at " + str(i))

    # Test case 7: Verify known output (RFC 4648 test vector)
    # "Man" (3 bytes) -> "TWFu" (no padding)
    var man_data = List[UInt8]()
    man_data.append(77)   # M
    man_data.append(97)   # a
    man_data.append(110)  # n
    var man_enc = encode(man_data)
    if man_enc != "TWFu":
        raise Error("RFC 4648 'Man' encoding failed: " + man_enc)

    # "Ma" (2 bytes) -> "TWE=" (1 padding)
    var ma_data = List[UInt8]()
    ma_data.append(77)  # M
    ma_data.append(97)  # a
    var ma_enc = encode(ma_data)
    if ma_enc != "TWE=":
        raise Error("RFC 4648 'Ma' encoding failed: " + ma_enc)

    # "M" (1 byte) -> "TQ==" (2 padding)
    var m_data = List[UInt8]()
    m_data.append(77)  # M
    var m_enc = encode(m_data)
    if m_enc != "TQ==":
        raise Error("RFC 4648 'M' encoding failed: " + m_enc)

    print("✓ SIMD-optimized encoding works correctly")


fn main() raises:
    print("Running Base64 tests...\n")

    test_encode_basic()
    test_encode_empty()
    test_encode_padding()
    test_decode_basic()
    test_decode_padding()
    test_roundtrip()
    test_urlsafe_encode()
    test_urlsafe_decode()
    test_streaming_encoder()
    test_streaming_decoder()
    test_binary_data()
    test_simd_encoding()

    print("\n✅ All Base64 tests passed!")
