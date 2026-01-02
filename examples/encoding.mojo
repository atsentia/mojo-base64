"""Base64 encoding examples."""
from mojo_base64 import encode_string, decode_to_string, urlsafe_encode_string

fn main() raises:
    var message = "Hello, Mojo! 🔥"
    
    # Standard Base64
    var encoded = encode_string(message)
    print("Encoded:", encoded)
    
    var decoded = decode_to_string(encoded)
    print("Decoded:", decoded)
    
    # URL-safe Base64 (no padding, safe for URLs)
    var url_encoded = urlsafe_encode_string(message)
    print("URL-safe:", url_encoded)
    
    # Binary data encoding
    var binary = List[UInt8]()
    binary.append(0x48)  # H
    binary.append(0x69)  # i
    var bin_encoded = encode(binary)
    print("Binary encoded:", bin_encoded)
