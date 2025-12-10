const std = @import("std");
const testing = std.testing;

const encoded_data = @import("encoded_data.zig");
const tree = @import("tree.zig");

/// Représente un code Huffman sous forme de bits
/// - bits: les bits du code, alignés à droite (ex: code "010" = 0b010 = 2)
/// - length: nombre de bits valides (1-32, mais typiquement < 20)
pub const HuffmanCode = struct {
    bits: u32,
    length: u5,

    pub fn format(self: HuffmanCode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        // fmt and options are needed for zig's formatting
        // but they are not needed in this implementation
        _ = fmt;
        _ = options;
        if (self.length == 0) return;
        var i: u5 = self.length;
        while (i > 0) {
            i -= 1;
            const bit: u1 = @intCast((self.bits >> i) & 1);
            try writer.writeByte('0' + bit);
        }
    }
};

pub const Encoder = struct {
    codes: std.AutoHashMap(u8, HuffmanCode),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Encoder {
        return .{
            .codes = std.AutoHashMap(u8, HuffmanCode).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Encoder) void {
        self.codes.deinit();
    }

    pub fn generateCodes(self: *Encoder, root: *tree.Node) !void {
        var code = try std.ArrayList(u8).initCapacity(self.allocator, 64);
        defer code.deinit(self.allocator);

        try self.generateCodesHelper(root, &code);
    }

    // This is a Depth First Algorithm to traverse the Huffman Tree.
    // Consider this simple Huffman tree:
    //       Root
    //      /    \
    //     0      1
    //    / \    / \
    //   A   B  C   D
    //
    // Example execution trace:
    // 1. Start:           code = []
    // 2. Go left:         code = ['0']
    // 3. Reach 'A':       Store "0" for 'A', pop
    // 4. Back at root:    code = []
    // 5. Go left, right:  code = ['0', '1']
    // 6. Reach 'B':       Store "01" for 'B', pop
    // 7. Back at root:    code = []
    // 8. Go right:        code = ['1']
    // 9. Go left:         code = ['1', '0']
    // 10. Reach 'C':      Store "10" for 'C', pop
    // 11. Back at '1':    code = ['1']
    // 12. Go right:       code = ['1', '1']
    // 13. Reach 'D':      Store "11" for 'D', pop
    // 14. Finished:       code = []
    //
    fn generateCodesHelper(self: *Encoder, node: *tree.Node, code: *std.ArrayList(u8)) !void {
        // We insert each time we reach a leaf node
        if (node.left == null and node.right == null) {
            try self.storeCode(node.character, code.items);
            return;
        }

        if (node.left) |left_child| {
            try code.append(self.allocator, '0');
            try self.generateCodesHelper(left_child, code);
            _ = code.pop();
        }

        if (node.right) |right_child| {
            try code.append(self.allocator, '1');
            try self.generateCodesHelper(right_child, code);
            _ = code.pop();
        }
    }

    fn storeCode(self: *Encoder, character: u8, code: []const u8) !void {
        var bits: u32 = 0;
        for (code) |c| {
            bits = (bits << 1) | @intFromBool(c == '1');
        }
        const huffman_code = HuffmanCode{ .bits = bits, .length = @intCast(code.len) };
        try self.codes.put(character, huffman_code);
    }

    pub fn encode(self: *Encoder, text: []const u8) ![]u8 {
        var encoded_result = try encoded_data.BitWriter.init(self.allocator);

        for (text) |char| {
            const code = self.codes.get(char) orelse {
                return error.CharacterNotInCodeTable;
            };
            var i: u5 = code.length;
            while (i > 0) {
                i -= 1;
                const bit: u1 = @intCast(((code.bits >> i) & 1));
                try encoded_result.writeBit(bit);
            }
        }
        return encoded_result.toOwnedSlice();
    }
};

test "Huffman Encoding" {
    var allocator = testing.allocator;

    var root = try tree.Node.init(allocator, 0, 100);
    defer tree.freeNode(allocator, root);

    root.left = try tree.Node.init(allocator, 'a', 45);
    root.right = try tree.Node.init(allocator, 0, 55);
    root.right.?.left = try tree.Node.init(allocator, 'b', 25);
    root.right.?.right = try tree.Node.init(allocator, 'c', 30);

    var encoder = Encoder.init(allocator);
    defer encoder.deinit();

    try encoder.generateCodes(root);

    // Expected HuffmanCode values: 'a' = 0 (1 bit), 'b' = 10 (2 bits), 'c' = 11 (2 bits)
    const code_a = encoder.codes.get('a') orelse unreachable;
    try testing.expectEqual(@as(u32, 0b0), code_a.bits);
    try testing.expectEqual(@as(u5, 1), code_a.length);

    const code_b = encoder.codes.get('b') orelse unreachable;
    try testing.expectEqual(@as(u32, 0b10), code_b.bits);
    try testing.expectEqual(@as(u5, 2), code_b.length);

    const code_c = encoder.codes.get('c') orelse unreachable;
    try testing.expectEqual(@as(u32, 0b11), code_c.bits);
    try testing.expectEqual(@as(u5, 2), code_c.length);

    // Encode "abcaba" = 0 + 10 + 11 + 0 + 10 + 0 = 010110100 (9 bits = 2 bytes, padded)
    const encoded = try encoder.encode("abcaba");
    defer allocator.free(encoded);

    // Bits padded to bytes: 01011010 0xxxxxxx = 0x5A, 0x00
    try testing.expectEqual(@as(usize, 2), encoded.len);
    try testing.expectEqual(@as(u8, 0b01011010), encoded[0]);
    // Second byte: last bit (0) in MSB position
    try testing.expectEqual(@as(u8, 0b00000000), encoded[1]);
}
