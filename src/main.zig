const std = @import("std");
const fs = std.fs;

const encoded_data = @import("encoded_data.zig");
const encoder = @import("encoder.zig");
const helpers = @import("helpers.zig");
const tree = @import("tree.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try helpers.parseArgs(allocator);
    defer {
        allocator.free(args.input_filename);
        allocator.free(args.output_filename);
    }

    if (args.help) {
        const help_text =
            \\Usage: huffman --input <file> --output <file> [options]
            \\
            \\Options:
            \\  --input <file>     Input file to encode/decode (required)
            \\  --output <file>    Output file (required)
            \\  --decode           Decode mode (default: encode)
            \\  --help             Display this help message
            \\
            \\Examples:
            \\  huffman --input text.txt --output text.huff
            \\  huffman --decode --input text.huff --output decoded.txt
            \\
        ;
        std.debug.print("{s}", .{help_text});
        return;
    }

    if (args.decode) {
        const e_data = encoded_data.readEncodedFile(args.input_filename, allocator) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.debug.print("File not found: {s}\n", .{args.input_filename});
                    return;
                },
                else => return err,
            }
        };
        defer allocator.free(e_data.data);
        var bit_reader = encoded_data.BitReader.init(e_data.data);

        const root = try tree.reconstructTree(allocator, &bit_reader);
        defer tree.freeNode(allocator, root);

        const decoded = try encoded_data.decodeText(&bit_reader, root, e_data.last_byte_bit_count, allocator);
        defer allocator.free(decoded);

        try encoded_data.writeTextToFile(args.output_filename, decoded);
    } else {
        const input_file = fs.cwd().openFile(args.input_filename, .{}) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.debug.print("File not found: {s}\n", .{args.input_filename});
                    return;
                },
                else => return err,
            }
        };
        defer input_file.close();

        const input_text = try helpers.readEntireFile(allocator, input_file);
        defer allocator.free(input_text);

        var letter_counts = try helpers.countLetters(input_text, allocator);
        defer letter_counts.deinit();

        const root = try tree.PriorityQueue.buildTree(allocator, letter_counts);
        defer tree.freeNode(allocator, root);

        var huffman_encoder = encoder.Encoder.init(allocator);
        defer huffman_encoder.deinit();
        try huffman_encoder.generateCodes(root);

        const encoded = try huffman_encoder.encode(input_text);
        defer allocator.free(encoded);

        try helpers.writeEncodedToFile(args.output_filename, root, encoded, allocator);

        helpers.printStatistics(input_text, encoded);
    }
}
