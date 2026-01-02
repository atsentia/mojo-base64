# mojo-base64

Pure Mojo Base64 encoding/decoding with URL-safe variant support.

## Features

- **Standard Base64** - RFC 4648 compliant encoding
- **URL-safe Base64** - Safe for URLs and filenames
- **Streaming API** - Encoder/Decoder classes for large data
- **Zero Dependencies** - Pure Mojo implementation

## Installation

```bash
pixi add mojo-base64
```

## Quick Start

### Standard Base64

```mojo
from mojo_base64 import encode_string, decode_to_string

var encoded = encode_string("Hello World!")
print(encoded)  # "SGVsbG8gV29ybGQh"

var decoded = decode_to_string(encoded)
print(decoded)  # "Hello World!"
```

### URL-safe Base64

```mojo
from mojo_base64 import urlsafe_encode_string, urlsafe_decode_to_string

var encoded = urlsafe_encode_string("Hello World!")
# No padding, uses - and _ instead of + and /
```

### Binary Data

```mojo
from mojo_base64 import encode, decode

var data = List[UInt8]()
data.append(0x01)
data.append(0x02)

var encoded = encode(data)
var decoded = decode(encoded)
```

## API Reference

| Function | Description |
|----------|-------------|
| `encode(data)` | Encode bytes to Base64 bytes |
| `encode_string(text)` | Encode string to Base64 string |
| `decode(data)` | Decode Base64 bytes to bytes |
| `decode_to_string(text)` | Decode Base64 string to string |
| `urlsafe_encode(data)` | URL-safe encode (no padding) |
| `urlsafe_decode(data)` | URL-safe decode |

## Testing

```bash
mojo run tests/test_base64.mojo
```

## License

MIT

## Part of mojo-contrib

This library is part of [mojo-contrib](https://github.com/atsentia/mojo-contrib), a collection of pure Mojo libraries.
