const std = @import("std");
const testing = std.testing;

const tree = @import("tree.zig");

pub const Encoder = struct {
    codes: std.AutoHashMap(u8, []const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Encoder {
        return .{
            .codes = std.AutoHashMap(u8, []const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Encoder) void {
        var it = self.codes.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
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
        const code_copy = try self.allocator.dupe(u8, code);
        try self.codes.put(character, code_copy);
    }

    pub fn encode(self: *Encoder, text: []const u8) ![]u8 {
        var encoded_result = try std.ArrayList(u8).initCapacity(self.allocator, text.len * 8);
        defer encoded_result.deinit(self.allocator);

        for (text) |char| {
            const code = self.codes.get(char) orelse {
                return error.CharacterNotInCodeTable;
            };
            try encoded_result.appendSlice(self.allocator, code);
        }
        return encoded_result.toOwnedSlice(self.allocator);
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

    try testing.expectEqualStrings("0", encoder.codes.get('a') orelse unreachable);
    try testing.expectEqualStrings("10", encoder.codes.get('b') orelse unreachable);
    try testing.expectEqualStrings("11", encoder.codes.get('c') orelse unreachable);

    const encoded = try encoder.encode("abcaba");
    defer allocator.free(encoded);

    try testing.expectEqualStrings("010110100", encoded);
}
