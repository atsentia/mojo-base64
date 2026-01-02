"""
Base64 Encoding/Decoding

Pure Mojo Base64 implementation.
Supports standard (RFC 4648) and URL-safe variants.

Performance: SIMD-optimized encoding processes 12 bytes at a time
(4 groups of 3 input bytes -> 16 output Base64 characters).
"""

from sys.info import simdwidthof


# =============================================================================
# Constants
# =============================================================================

# Standard Base64 alphabet (RFC 4648)
alias STANDARD_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

# URL-safe Base64 alphabet (RFC 4648 Section 5)
alias URLSAFE_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

# Padding character
alias PAD = "="

# SIMD chunk size: process 12 input bytes -> 16 output chars
alias SIMD_CHUNK_INPUT = 12
alias SIMD_CHUNK_OUTPUT = 16


# =============================================================================
# Encoding Functions
# =============================================================================

fn encode(data: List[UInt8]) -> String:
    """
    Encode bytes to standard Base64.

    Args:
        data: Bytes to encode.

    Returns:
        Base64-encoded string with padding.

    Example:
        var result = encode(bytes)  # "SGVsbG8gV29ybGQh"
    """
    return _encode_with_alphabet(data, STANDARD_ALPHABET, pad=True)


fn encode_string(s: String) -> String:
    """
    Encode string to standard Base64.

    Args:
        s: String to encode.

    Returns:
        Base64-encoded string with padding.
    """
    return encode(_string_to_bytes(s))


fn urlsafe_encode(data: List[UInt8]) -> String:
    """
    Encode bytes to URL-safe Base64.

    Uses '-' and '_' instead of '+' and '/'.
    No padding by default (common for URLs).

    Args:
        data: Bytes to encode.

    Returns:
        URL-safe Base64-encoded string without padding.
    """
    return _encode_with_alphabet(data, URLSAFE_ALPHABET, pad=False)


fn urlsafe_encode_string(s: String) -> String:
    """
    Encode string to URL-safe Base64.

    Args:
        s: String to encode.

    Returns:
        URL-safe Base64-encoded string without padding.
    """
    return urlsafe_encode(_string_to_bytes(s))


fn _build_lookup_table(alphabet: String) -> List[UInt8]:
    """Build a 64-byte lookup table from the alphabet string."""
    var table = List[UInt8](capacity=64)
    for i in range(64):
        table.append(UInt8(ord(alphabet[i])))
    return table


fn _encode_simd_chunk(
    data: List[UInt8],
    offset: Int,
    lookup: List[UInt8],
    inout output: List[UInt8],
):
    """
    SIMD-optimized encoding of 12 input bytes -> 16 output Base64 chars.

    Processes 4 groups of 3 bytes in parallel using SIMD operations
    for the bit manipulation (shift, mask, OR operations).
    """
    # Load 12 bytes as 4 groups of 3 bytes each
    # Group 0: bytes 0,1,2 -> chars 0,1,2,3
    # Group 1: bytes 3,4,5 -> chars 4,5,6,7
    # Group 2: bytes 6,7,8 -> chars 8,9,10,11
    # Group 3: bytes 9,10,11 -> chars 12,13,14,15

    # Load 4 sets of b0 values (bytes at positions 0, 3, 6, 9)
    var b0_vec = SIMD[DType.uint32, 4](
        Int(data[offset + 0]),
        Int(data[offset + 3]),
        Int(data[offset + 6]),
        Int(data[offset + 9]),
    )

    # Load 4 sets of b1 values (bytes at positions 1, 4, 7, 10)
    var b1_vec = SIMD[DType.uint32, 4](
        Int(data[offset + 1]),
        Int(data[offset + 4]),
        Int(data[offset + 7]),
        Int(data[offset + 10]),
    )

    # Load 4 sets of b2 values (bytes at positions 2, 5, 8, 11)
    var b2_vec = SIMD[DType.uint32, 4](
        Int(data[offset + 2]),
        Int(data[offset + 5]),
        Int(data[offset + 8]),
        Int(data[offset + 11]),
    )

    # Compute 4 sets of 6-bit indices using SIMD bit operations
    # idx0 = (b0 >> 2) & 0x3F
    var idx0_vec = (b0_vec >> 2) & 0x3F

    # idx1 = ((b0 << 4) | (b1 >> 4)) & 0x3F
    var idx1_vec = ((b0_vec << 4) | (b1_vec >> 4)) & 0x3F

    # idx2 = ((b1 << 2) | (b2 >> 6)) & 0x3F
    var idx2_vec = ((b1_vec << 2) | (b2_vec >> 6)) & 0x3F

    # idx3 = b2 & 0x3F
    var idx3_vec = b2_vec & 0x3F

    # Perform lookup for all 16 indices and write to output
    # The lookup is still scalar, but the bit manipulation was SIMD
    @parameter
    for group in range(4):
        var base_out = group * 4
        output.append(lookup[Int(idx0_vec[group])])
        output.append(lookup[Int(idx1_vec[group])])
        output.append(lookup[Int(idx2_vec[group])])
        output.append(lookup[Int(idx3_vec[group])])


fn _encode_scalar_triple(
    data: List[UInt8],
    offset: Int,
    lookup: List[UInt8],
    inout output: List[UInt8],
):
    """Encode a single group of 3 bytes -> 4 Base64 chars (scalar fallback)."""
    var b0 = Int(data[offset])
    var b1 = Int(data[offset + 1])
    var b2 = Int(data[offset + 2])

    output.append(lookup[(b0 >> 2) & 0x3F])
    output.append(lookup[((b0 << 4) | (b1 >> 4)) & 0x3F])
    output.append(lookup[((b1 << 2) | (b2 >> 6)) & 0x3F])
    output.append(lookup[b2 & 0x3F])


fn _encode_with_alphabet(data: List[UInt8], alphabet: String, pad: Bool) -> String:
    """
    Internal encoding with configurable alphabet and padding.

    Uses SIMD optimization to process 12 bytes at a time (4 groups of 3 bytes
    -> 16 output characters). Falls back to scalar processing for remaining bytes.
    """
    if len(data) == 0:
        return ""

    var n = len(data)

    # Calculate output size: ceil(n / 3) * 4, plus possible padding
    var output_size = ((n + 2) // 3) * 4
    var output = List[UInt8](capacity=output_size)

    # Build lookup table for fast alphabet access
    var lookup = _build_lookup_table(alphabet)

    var i = 0

    # SIMD path: process 12 bytes at a time (4 groups of 3 bytes -> 16 chars)
    while i + SIMD_CHUNK_INPUT <= n:
        _encode_simd_chunk(data, i, lookup, output)
        i += SIMD_CHUNK_INPUT

    # Scalar path: process remaining complete 3-byte groups
    while i + 3 <= n:
        _encode_scalar_triple(data, i, lookup, output)
        i += 3

    # Handle remaining bytes (0, 1, or 2) with padding
    var remaining = n - i

    if remaining == 1:
        var b0 = Int(data[i])
        output.append(lookup[(b0 >> 2) & 0x3F])
        output.append(lookup[(b0 << 4) & 0x3F])
        if pad:
            output.append(UInt8(ord("=")))
            output.append(UInt8(ord("=")))
    elif remaining == 2:
        var b0 = Int(data[i])
        var b1 = Int(data[i + 1])
        output.append(lookup[(b0 >> 2) & 0x3F])
        output.append(lookup[((b0 << 4) | (b1 >> 4)) & 0x3F])
        output.append(lookup[(b1 << 2) & 0x3F])
        if pad:
            output.append(UInt8(ord("=")))

    # Convert output bytes to string
    var result = String()
    for j in range(len(output)):
        result += chr(Int(output[j]))

    return result


# =============================================================================
# Decoding Functions
# =============================================================================

fn decode(encoded: String) raises -> List[UInt8]:
    """
    Decode standard Base64 to bytes.

    Args:
        encoded: Base64-encoded string.

    Returns:
        Decoded bytes.

    Raises:
        Error: If input contains invalid Base64 characters.

    Example:
        var bytes = decode("SGVsbG8gV29ybGQh")
    """
    return _decode_with_alphabet(encoded, STANDARD_ALPHABET)


fn decode_to_string(encoded: String) raises -> String:
    """
    Decode standard Base64 to string.

    Args:
        encoded: Base64-encoded string.

    Returns:
        Decoded string.
    """
    return _bytes_to_string(decode(encoded))


fn urlsafe_decode(encoded: String) raises -> List[UInt8]:
    """
    Decode URL-safe Base64 to bytes.

    Handles input with or without padding.

    Args:
        encoded: URL-safe Base64-encoded string.

    Returns:
        Decoded bytes.
    """
    return _decode_with_alphabet(encoded, URLSAFE_ALPHABET)


fn urlsafe_decode_to_string(encoded: String) raises -> String:
    """
    Decode URL-safe Base64 to string.

    Args:
        encoded: URL-safe Base64-encoded string.

    Returns:
        Decoded string.
    """
    return _bytes_to_string(urlsafe_decode(encoded))


fn _decode_with_alphabet(encoded: String, alphabet: String) raises -> List[UInt8]:
    """Internal decoding with configurable alphabet."""
    if len(encoded) == 0:
        return List[UInt8]()

    # Build reverse lookup table
    var lookup = List[Int]()
    for _ in range(256):
        lookup.append(-1)

    for i in range(64):
        var c = alphabet[i]
        lookup[ord(c)] = i

    # Remove padding and whitespace
    var clean = String()
    for i in range(len(encoded)):
        var c = encoded[i]
        if c != "=" and c != " " and c != "\n" and c != "\r" and c != "\t":
            clean += c

    var result = List[UInt8]()
    var i = 0
    var n = len(clean)

    # Process 4 characters at a time -> 3 bytes
    while i + 3 < n:
        var v0 = lookup[ord(clean[i])]
        var v1 = lookup[ord(clean[i + 1])]
        var v2 = lookup[ord(clean[i + 2])]
        var v3 = lookup[ord(clean[i + 3])]

        if v0 < 0 or v1 < 0 or v2 < 0 or v3 < 0:
            raise Error("Invalid Base64 character at position " + str(i))

        result.append(UInt8(((v0 << 2) | (v1 >> 4)) & 0xFF))
        result.append(UInt8(((v1 << 4) | (v2 >> 2)) & 0xFF))
        result.append(UInt8(((v2 << 6) | v3) & 0xFF))

        i += 4

    # Handle remaining characters (0, 2, or 3)
    var remaining = n - i

    if remaining == 2:
        var v0 = lookup[ord(clean[i])]
        var v1 = lookup[ord(clean[i + 1])]
        if v0 < 0 or v1 < 0:
            raise Error("Invalid Base64 character")
        result.append(UInt8(((v0 << 2) | (v1 >> 4)) & 0xFF))
    elif remaining == 3:
        var v0 = lookup[ord(clean[i])]
        var v1 = lookup[ord(clean[i + 1])]
        var v2 = lookup[ord(clean[i + 2])]
        if v0 < 0 or v1 < 0 or v2 < 0:
            raise Error("Invalid Base64 character")
        result.append(UInt8(((v0 << 2) | (v1 >> 4)) & 0xFF))
        result.append(UInt8(((v1 << 4) | (v2 >> 2)) & 0xFF))

    return result


# =============================================================================
# Helper Functions
# =============================================================================

fn _string_to_bytes(s: String) -> List[UInt8]:
    """Convert string to bytes."""
    var result = List[UInt8]()
    for i in range(len(s)):
        result.append(UInt8(ord(s[i])))
    return result


fn _bytes_to_string(data: List[UInt8]) -> String:
    """Convert bytes to string."""
    var result = String()
    for i in range(len(data)):
        result += chr(Int(data[i]))
    return result


# =============================================================================
# Base64 Encoder/Decoder Structs (for streaming)
# =============================================================================

struct Base64Encoder:
    """
    Streaming Base64 encoder.

    Example:
        var encoder = Base64Encoder()
        encoder.update(chunk1)
        encoder.update(chunk2)
        var result = encoder.finalize()
    """
    var buffer: List[UInt8]
    var alphabet: String
    var use_padding: Bool

    fn __init__(out self, urlsafe: Bool = False, padding: Bool = True):
        """Create encoder with optional URL-safe alphabet."""
        self.buffer = List[UInt8]()
        if urlsafe:
            self.alphabet = URLSAFE_ALPHABET
            self.use_padding = False  # URL-safe typically no padding
        else:
            self.alphabet = STANDARD_ALPHABET
            self.use_padding = padding

    fn update(inout self, data: List[UInt8]):
        """Add bytes to encode."""
        for i in range(len(data)):
            self.buffer.append(data[i])

    fn finalize(self) -> String:
        """Finalize encoding and return Base64 string."""
        return _encode_with_alphabet(self.buffer, self.alphabet, self.use_padding)


struct Base64Decoder:
    """
    Streaming Base64 decoder.

    Example:
        var decoder = Base64Decoder()
        decoder.update(chunk1)
        decoder.update(chunk2)
        var result = decoder.finalize()
    """
    var buffer: String
    var alphabet: String

    fn __init__(out self, urlsafe: Bool = False):
        """Create decoder with optional URL-safe alphabet."""
        self.buffer = String()
        if urlsafe:
            self.alphabet = URLSAFE_ALPHABET
        else:
            self.alphabet = STANDARD_ALPHABET

    fn update(inout self, data: String):
        """Add Base64 string to decode."""
        self.buffer += data

    fn finalize(self) raises -> List[UInt8]:
        """Finalize decoding and return bytes."""
        return _decode_with_alphabet(self.buffer, self.alphabet)
