
# Huffman Encoding Project

A complete Huffman encoder/decoder implementation in Zig. This project is a deliberate practice exercise to become more familiar with low-level programming and memory management, inspired by the coding challenge found [here](https://codingchallenges.fyi/challenges/challenge-huffman/#the-challenge---building-a-huffman-encoderdecoder).

## Features

- Full Huffman compression and decompression
- Binary tree serialization/deserialization
- Bit-level I/O operations
- Dynamic buffer management
- Works on any file type (optimized for text)

## Requirements

- Zig 0.15.2 or later

Install Zig by following the instructions from the official [Zig website](https://ziglang.org/download/).

## Build

```sh
zig build
```

## Usage

### Encode (compress)

```sh
./zig-out/bin/huffman --input <file> --output <compressed_file>
```

### Decode (decompress)

```sh
./zig-out/bin/huffman --decode --input <compressed_file> --output <decompressed_file>
```

### Example

```sh
# Compress a text file
./zig-out/bin/huffman --input book.txt --output book.huff

# Decompress it back
./zig-out/bin/huffman --decode --input book.huff --output book_decoded.txt

# Verify the files are identical
diff book.txt book_decoded.txt
```

## Performance

Huffman encoding works best on files with non-uniform byte distribution:

| File Type | Typical Compression Ratio |
|-----------|---------------------------|
| Plain text | 1.5x - 2x |
| Source code | 1.5x - 1.8x |
| Already compressed (PDF, JPG, ZIP) | ~1x (no gain) |

Example on a 750KB text file:
```
Original: 752583 bytes
Encoded:  434232 bytes
Compression ratio: 1.73
```

## How It Works

1. **Frequency Analysis**: Count byte occurrences in the input file
2. **Tree Construction**: Build a Huffman tree using a priority queue
3. **Code Generation**: Generate variable-length binary codes (frequent bytes get shorter codes)
4. **Encoding**: Replace each byte with its Huffman code
5. **Serialization**: Store the tree and encoded data in the output file

The compressed file format:
```
[serialized tree][encoded data][padding info (1 byte)]
```

## Project Structure

```
src/
  main.zig         - Entry point, CLI handling
  tree.zig         - Huffman tree and priority queue
  encoder.zig      - Code generation and encoding
  encoded_data.zig - BitReader/BitWriter, decoding
  helpers.zig      - File I/O, argument parsing
```

## Learning Objective

This project was built to practice:
- Manual memory management with allocators
- Bit manipulation and binary I/O
- Tree data structures
- Low-level file operations
- Zig's type system and error handling

## Acknowledgments

Based on the Huffman encoding challenge from [Coding Challenges](https://codingchallenges.fyi/challenges/challenge-huffman/#the-challenge---building-a-huffman-encoderdecoder).
