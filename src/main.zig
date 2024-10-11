const std = @import("std");
const tree = @import("tree.zig");

const fs = std.fs;
const io = std.io;
const ascii = std.ascii;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const text_file = try fs.cwd().openFile("135-0.txt", .{ .mode = .read_only });
    defer text_file.close();

    var buffered = io.bufferedReader(text_file.reader());
    const reader = buffered.reader();

    var letter_counts = try countLetters(reader, allocator);
    defer letter_counts.deinit();

    const root = try tree.PriorityQueue.buildTree(allocator, letter_counts);
    defer tree.freeNode(allocator, root);

    std.debug.print("Detailed Huffman Tree:\n", .{});
    tree.printTree(root, 0);
}

pub fn countLetters(reader: anytype, allocator: std.mem.Allocator) !std.AutoHashMap(u8, usize) {
    var letter_counts = std.AutoHashMap(u8, usize).init(allocator);
    errdefer letter_counts.deinit();

    while (true) {
        const byte = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        if (ascii.isASCII(byte)) {
            const result = try letter_counts.getOrPut(byte);
            if (!result.found_existing) {
                result.value_ptr.* = 0;
            }
            result.value_ptr.* += 1;
        }
    }

    return letter_counts;
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
