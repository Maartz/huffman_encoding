const tree = @import("tree.zig");
const encoder = @import("encoder.zig");
const helpers = @import("helpers.zig");

const std = @import("std");
const fs = std.fs;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try helpers.parseArgs(allocator);
    defer {
        allocator.free(args.input_filename);
        allocator.free(args.output_filename);
        if (args.tree_filename) |tf| allocator.free(tf);
    }

    const input_file = try fs.cwd().openFile(args.input_filename, .{});
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

    try helpers.writeEncodedToFile(args.output_filename, encoded);

    helpers.printStatistics(input_text, encoded);
}
