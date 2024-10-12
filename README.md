
# Huffman Encoding Project

This project is a deliberate practice exercise to become more familiar with memory-managed languages, specifically using the Zig programming language. The challenge tackled here is implementing a Huffman Encoder/Decoder, an idea inspired by the coding challenge found [here](https://codingchallenges.fyi/challenges/challenge-huffman/#the-challenge---building-a-huffman-encoderdecoder).

## Requirements

To compile and run this project, you must have Zig installed from the `@master` branch. You can install Zig by following the instructions from the official [Zig website](https://ziglang.org/download/).

## Compilation

To compile the project, simply run:

```sh
zig build
```

## Usage

Once compiled, the program can be run with the following parameters:

- `--input <file.txt>`: The input file that contains the data to be encoded.
- `--output <myencodeddata>`: The output file where the encoded data will be written.
- `--tree <huffman_tree_file>` (optional): An optional parameter to pass your own text to generate a Huffman tree used for encoding.

### Example

```sh
./huffman --input file.txt --output encoded_output --tree my_tree.txt
```

If you omit the `--tree` parameter, the program will generate its own Huffman tree based on a specific file in the project `135-0.txt`.

## Learning Objective

The purpose of this project is to practice working with a memory-managed language and to implement a classic compression algorithm from scratch.

## Acknowledgments

This project is based on the Huffman encoding challenge found at [Coding Challenges](https://codingchallenges.fyi/challenges/challenge-huffman/#the-challenge---building-a-huffman-encoderdecoder).
