const std = @import("std");
const fs = std.fs;
const io = std.io;
const ascii = std.ascii;

pub fn printStatistics(original: []const u8, encoded: []const u8) void {
    const original_bytes = original.len;
    const encoded_bytes = (encoded.len + 7) / 8; // Round up to nearest byte

    std.debug.print("\nByte count comparison:\n", .{});
    std.debug.print("Original: {} bytes\n", .{original_bytes});
    std.debug.print("Encoded:  {} bytes\n", .{encoded_bytes});

    const compression_ratio = @as(f32, @floatFromInt(original_bytes)) / @as(f32, @floatFromInt(encoded_bytes));
    std.debug.print("Compression ratio: {d:.2}\n", .{compression_ratio});
}

pub fn parseArgs(allocator: std.mem.Allocator) !struct {
    input_filename: []const u8,
    output_filename: []const u8,
    tree_filename: ?[]const u8,
} {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var input_filename: ?[]const u8 = null;
    var output_filename: ?[]const u8 = null;
    var tree_filename: ?[]const u8 = null;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--input")) {
            if (i + 1 < args.len) {
                input_filename = try allocator.dupe(u8, args[i + 1]);
            } else {
                return error.MissingInputFilename;
            }
            i += 1;
        }

        if (std.mem.eql(u8, args[i], "--output")) {
            if (i + 1 < args.len) {
                output_filename = try allocator.dupe(u8, args[i + 1]);
            } else {
                return error.MissingOutputFilename;
            }
            i += 1;
        }

        if (std.mem.eql(u8, args[i], "--tree")) {
            if (i + 1 < args.len) {
                tree_filename = try allocator.dupe(u8, args[i + 1]);
            }
            i += 1;
        }
    }

    if (input_filename == null or output_filename == null) {
        return error.MissingMandatoryArgument;
    }

    return .{
        .input_filename = input_filename.?,
        .output_filename = output_filename.?,
        .tree_filename = tree_filename,
    };
}

pub fn readEntireFile(allocator: std.mem.Allocator, file: fs.File) ![]u8 {
    // TODO: Adding a maximum file size limit to prevent excessive memory usage (something like 1MB)
    // Caveat: This assumes the file isn't being modified while we're reading it
    const file_size = try file.getEndPos();

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
        const result = try letter_counts.getOrPut(byte);
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* += 1;
    }

    return letter_counts;
}

pub fn writeEncodedToFile(filename: []const u8, encoded: []const u8) !void {
    const file = try fs.cwd().createFile(filename, .{});
    defer file.close();

    var writer = file.writer();

    // Buffer to hold a byte for packing bits
    var byte: u8 = 0;
    var bit_count: u3 = 0;
    var total_bits: usize = 0;

    for (encoded) |bit_char| {
        const bit = @as(u1, @intCast(bit_char - '0'));

        // Pack the bit into the current byte
        byte = (byte << 1) | bit;
        bit_count +%= 1;
        total_bits += 1;

        // it's gonna be 0 after wrapping +%=
        if (bit_count == 0) {
            try writer.writeByte(byte);
            byte = 0;
        }
    }

    // Pad with zeros
    if (bit_count != 0) {
        byte <<= @as(u3, 0) -% bit_count;
        try writer.writeByte(byte);
    }

    // Necessary for decoding, :^) will be done later
    try writer.writeByte(@as(u8, @intCast(bit_count)));
}

const testing = std.testing;

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
