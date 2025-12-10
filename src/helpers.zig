const std = @import("std");
const fs = std.fs;
const io = std.io;
const ascii = std.ascii;
const testing = std.testing;

const encoded_data = @import("encoded_data.zig");
const encoder = @import("encoder.zig");
const tree = @import("tree.zig");

pub fn printStatistics(original: []const u8, encoded: encoder.EncodedResult) void {
    const original_bytes = original.len;
    const encoded_bytes = (encoded.data.len + 7) / 8; // Round up to nearest byte

    std.debug.print("\nByte count comparison:\n", .{});
    std.debug.print("Original: {} bytes\n", .{original_bytes});
    std.debug.print("Encoded:  {} bytes\n", .{encoded_bytes});

    const compression_ratio = @as(f32, @floatFromInt(original_bytes)) / @as(f32, @floatFromInt(encoded_bytes));
    std.debug.print("Compression ratio: {d:.2}\n", .{compression_ratio});
}

const Arg = enum { input, output, decode, help, unknown };

pub fn parseArgs(allocator: std.mem.Allocator) !struct { input_filename: []const u8, output_filename: []const u8, decode: bool, help: bool } {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var input_filename: ?[]const u8 = null;
    var output_filename: ?[]const u8 = null;
    var decode = false;
    var help = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        switch (parseArg(args[i])) {
            .input => {
                if (i + 1 < args.len) {
                    input_filename = try allocator.dupe(u8, args[i + 1]);
                } else {
                    return error.MissingInputFilename;
                }
                i += 1;
            },
            .output => {
                if (i + 1 < args.len) {
                    output_filename = try allocator.dupe(u8, args[i + 1]);
                } else {
                    return error.MissingOutputFilename;
                }
                i += 1;
            },
            .decode => {
                decode = true;
            },
            .help => {
                help = true;
            },
            else => {
                return error.UnknownArgument;
            },
        }
    }

    if (help) {
        return .{
            .input_filename = "",
            .output_filename = "",
            .decode = false,
            .help = help,
        };
    }

    if (!help and input_filename == null or output_filename == null) {
        return error.MissingMandatoryArgument;
    }

    return .{
        .input_filename = input_filename.?,
        .output_filename = output_filename.?,
        .decode = decode,
        .help = false,
    };
}

pub fn readEntireFile(allocator: std.mem.Allocator, file: fs.File) ![]u8 {
    // 1MB limit
    const max_file_size = 1 * 1024 * 1024;

    // Caveat: This assumes the file isn't being modified while we're reading it
    const file_size = try file.getEndPos();

    if (file_size > max_file_size) {
        return error.FileTooLarge;
    }

    const buffer_size = std.math.cast(usize, file_size) orelse return error.FileTooLarge;
    const buffer = try allocator.alloc(u8, buffer_size);
    errdefer allocator.free(buffer);

    const bytes_read = try file.readAll(buffer);

    if (bytes_read != buffer_size) {
        return error.UnexpectedReadSize;
    }

    return buffer;
}

pub fn countLetters(input: []const u8, allocator: std.mem.Allocator) !std.AutoHashMap(u8, usize) {
    var letter_counts = std.AutoHashMap(u8, usize).init(allocator);
    errdefer letter_counts.deinit();

    for (input) |byte| {
        // TODO: upper or lower the byte to avoid X and x to be treated as 2 diff letters
        const result = try letter_counts.getOrPut(byte);
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* += 1;
    }

    return letter_counts;
}

pub fn writeEncodedToFile(filename: []const u8, root: *tree.Node, encoded: encoder.EncodedResult, allocator: std.mem.Allocator) !void {
    var bit_writer = try encoded_data.BitWriter.init(allocator);
    defer bit_writer.deinit();

    try tree.serializeTree(root, &bit_writer);

    for (encoded.data[0 .. encoded.data.len - 1]) |byte| {
        try bit_writer.writeByte(byte);
    }

    if (encoded.data.len > 0) {
        const last_byte = encoded.data[encoded.data.len - 1];
        const valid_bits: u4 = if (encoded.last_byte_bits == 0) 8 else @as(u4, encoded.last_byte_bits);
        for (0..valid_bits) |i| {
            const shift: u3 = @intCast(7 - i);
            const bit: u1 = @intCast((last_byte >> shift) & 1);
            try bit_writer.writeBit(bit);
        }
    }

    const last_byte_bit_count = bit_writer.bit_position;
    const data = bit_writer.finish();

    const file = try fs.cwd().createFile(filename, .{});
    defer file.close();

    var writer_buffer: [4096]u8 = undefined;
    var writer = file.writer(&writer_buffer).interface;
    try writer.writeAll(data);
    try writer.writeByte(@as(u8, last_byte_bit_count));
    try writer.flush();
}

fn compare(arg: []const u8, flag: []const u8) bool {
    return std.mem.eql(u8, arg, flag);
}

fn parseArg(str: []const u8) Arg {
    if (compare(str, "--input")) {
        return .input;
    } else if (compare(str, "--output")) {
        return .output;
    } else if (compare(str, "--decode")) {
        return .decode;
    } else if (compare(str, "--help")) {
        return .help;
    }
    return .unknown;
}

test "letter count assertions from file" {
    const allocator = testing.allocator;

    const text_file = try fs.cwd().openFile("135-0.txt", .{ .mode = .read_only });
    defer text_file.close();

    var buffered = io.bufferedReader(text_file.reader());
    const reader = buffered.reader();

    var letter_counts = try countLetters(reader, allocator);
    defer letter_counts.deinit();

    try testing.expectEqual(@as(usize, 333), letter_counts.get('X') orelse 0);
    try testing.expectEqual(@as(usize, 223000), letter_counts.get('t') orelse 0);
}
