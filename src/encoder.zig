const std = @import("std");
const tree = @import("tree.zig");
const testing = std.testing;

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
        var code = std.ArrayList(u8).init(self.allocator);
        defer code.deinit();

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
            std.debug.print("Stored code for '{}': {s}\n", .{ node.character, code.items });
            return;
        }

        if (node.left) |left_child| {
            try code.append('0');
            try self.generateCodesHelper(left_child, code);
            _ = code.pop();
        }

        if (node.right) |right_child| {
            try code.append('1');
            try self.generateCodesHelper(right_child, code);
            _ = code.pop();
        }
    }

    fn storeCode(self: *Encoder, character: u8, code: []const u8) !void {
        const code_copy = try self.allocator.dupe(u8, code);
        try self.codes.put(character, code_copy);
    }

    fn encode(self: *Encoder, text: []const u8) ![]u8 {
        var encoded_result = std.ArrayList(u8).init(self.allocator);
        // Maybe redundant as `ArrayList.toOwnedSlice`
        // pass the deinit step to the caller
        defer encoded_result.deinit();

        for (text) |char| {
            const code = self.codes.get(char) orelse {
                return error.CharacterNotInCodeTable;
            };
            std.debug.print("Character '{}' (ASCII {}): Code {s}\n", .{ char, char, code });
            try encoded_result.appendSlice(code);
            std.debug.print("Current encoded result: ", .{});
            for (encoded_result.items) |bit| {
                std.debug.print("{c}", .{bit});
            }
            std.debug.print("\n", .{});
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

    try testing.expectEqualStrings("0", encoder.codes.get('a') orelse unreachable);
    try testing.expectEqualStrings("10", encoder.codes.get('b') orelse unreachable);
    try testing.expectEqualStrings("11", encoder.codes.get('c') orelse unreachable);

    const encoded = try encoder.encode("abcaba");
    defer allocator.free(encoded);

    try testing.expectEqualStrings("010110100", encoded);
}
