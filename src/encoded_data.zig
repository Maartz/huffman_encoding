const std = @import("std");
const fs = std.fs;

const tree = @import("tree.zig");

pub const EncodedData = struct {
    data: []const u8,
    last_byte_bit_count: u3,
};

pub fn readEncodedFile(filename: []const u8, allocator: std.mem.Allocator) !EncodedData {
    const encoded_file = try fs.cwd().openFile(filename, .{});
    defer encoded_file.close();

    const encoded_file_size = try encoded_file.getEndPos() - @as(u64, 1);

    const buffer = try allocator.alloc(u8, encoded_file_size);
    errdefer allocator.free(buffer);

    var reader_buffer: [4096]u8 = undefined;
    var reader = encoded_file.reader(&reader_buffer);
    var interface = &reader.interface;
    try interface.readSliceAll(buffer);

    const last_byte = try interface.takeByte();

    return EncodedData{
        .last_byte_bit_count = @intCast(last_byte),
        .data = buffer,
    };
}

pub const BitReader = struct {
    data: []const u8,
    byte_index: usize,
    bit_position: u3,

    pub fn init(data: []const u8) BitReader {
        return .{
            .data = data,
            .byte_index = 0,
            .bit_position = 0,
        };
    }

    pub fn readBit(self: *BitReader) u1 {
        const byte = self.data[self.byte_index];
        const bit = (byte >> (7 - self.bit_position)) & 1;
        self.bit_position +%= 1;
        if (self.bit_position == 0) {
            self.byte_index += 1;
        }
        return @intCast(bit);
    }

    pub fn readByte(self: *BitReader) u8 {
        var byte: u8 = 0;
        for (0..8) |_| {
            byte = (byte << 1) | self.readBit();
        }
        return byte;
    }

    pub fn atEnd(self: *BitReader) bool {
        return self.byte_index >= self.data.len;
    }
};

pub const BitWriter = struct {
    data: std.ArrayList(u8),
    byte_index: usize,
    bit_position: u3,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !BitWriter {
        var data = try std.ArrayList(u8).initCapacity(allocator, 1024);
        try data.append(allocator, 0);
        return .{
            .data = data,
            .byte_index = 0,
            .bit_position = 0,
            .allocator = allocator,
        };
    }

    pub fn writeBit(self: *BitWriter, bit: u1) !void {
        const shift: u3 = 7 - self.bit_position;
        self.data.items[self.byte_index] |= @as(u8, bit) << shift;
        self.bit_position +%= 1;
        if (self.bit_position == 0) {
            self.byte_index += 1;
            try self.data.append(self.allocator, 0);
        }
    }

    pub fn writeByte(self: *BitWriter, byte: u8) !void {
        for (0..8) |i| {
            const shift: u3 = @intCast(7 - i);
            const bit: u1 = @intCast((byte >> shift) & 1);
            try self.writeBit(bit);
        }
    }

    pub fn deinit(self: *BitWriter) void {
        self.data.deinit(self.allocator);
    }

    pub fn finish(self: *BitWriter) []u8 {
        if (self.bit_position != 0) {
            self.byte_index += 1;
        }
        return self.data.items[0..self.byte_index];
    }

    pub fn toOwnedSlice(self: *BitWriter) ![]u8 {
        if (self.bit_position != 0) {
            self.byte_index += 1;
        }
        return self.data.toOwnedSlice(self.allocator);
    }
};

pub fn decodeText(reader: *BitReader, root: *tree.Node, last_byte_bit_count: u3, allocator: std.mem.Allocator) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, 64);
    errdefer result.deinit(allocator);

    var current_node = root;

    while (!reader.atEnd()) {
        const on_last_byte = reader.byte_index == reader.data.len - 1;
        const past_valid_bits = (last_byte_bit_count != 0) and (reader.bit_position >=
            last_byte_bit_count);

        if (on_last_byte and past_valid_bits) break;
        const bit = reader.readBit();
        if (bit == 0) {
            current_node = current_node.left.?;
        } else {
            current_node = current_node.right.?;
        }

        if (tree.isLeaf(current_node)) {
            try result.append(allocator, current_node.character);
            current_node = root;
        }
    }
    return try result.toOwnedSlice(allocator);
}

pub fn writeTextToFile(filename: []const u8, text: []const u8) !void {
    const file = try fs.cwd().createFile(filename, .{});
    defer file.close();

    var stdout_buffer: [4096]u8 = undefined;
    var writer = file.writer(&stdout_buffer);
    var interface = &writer.interface;
    try interface.writeAll(text);
    try interface.flush();
}
