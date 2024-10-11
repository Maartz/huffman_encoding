const std = @import("std");
const testing = std.testing;

const Node = struct {
    character: u8,
    frequency: usize,
    left: ?*Node,
    right: ?*Node,

    pub fn init(allocator: std.mem.Allocator, char: u8, freq: usize) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .character = char,
            .frequency = freq,
            .left = null,
            .right = null,
        };
        return node;
    }
};

pub const PriorityQueue = struct {
    nodes: []?*Node,
    len: usize,
    capacity: usize,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, capacity: usize) !PriorityQueue {
        const nodes = try allocator.alloc(?*Node, capacity);
        for (nodes) |*node| {
            node.* = null;
        }
        return PriorityQueue{ .allocator = allocator, .capacity = capacity, .len = 0, .nodes = nodes };
    }

    fn deinit(self: *PriorityQueue) void {
        self.allocator.free(self.nodes);
    }

    pub fn buildTree(allocator: std.mem.Allocator, freq_map: std.AutoHashMap(u8, usize)) !*Node {
        var pq = try PriorityQueue.init(allocator, freq_map.count());
        defer pq.deinit();

        var it = freq_map.iterator();
        while (it.next()) |entry| {
            const char = entry.key_ptr.*;
            const count = entry.value_ptr.*;
            const node = try Node.init(allocator, char, count);
            try pq.insert(node);
        }

        while (pq.len > 1) {
            const left = (try pq.remove()) orelse return error.UnexpectedNull;
            const right = (try pq.remove()) orelse return error.UnexpectedNull;

            const parent = try Node.init(allocator, 0, left.frequency + right.frequency);
            parent.left = left;
            parent.right = right;

            try pq.insert(parent);
        }

        return (try pq.remove()) orelse return error.EmptyQueue;
    }

    pub fn insert(self: *PriorityQueue, node: *Node) !void {
        if (self.len == self.capacity) {
            const new_capacity = self.capacity * 2;
            const new_nodes = try self.allocator.alloc(?*Node, new_capacity);
            @memcpy(new_nodes[0..self.len], self.nodes[0..self.len]);
            self.allocator.free(self.nodes);
            self.nodes = new_nodes;
            self.capacity = new_capacity;
        }
        self.nodes[self.len] = node;
        self.len += 1;
        self.bubbleUp(self.len - 1);
    }

    fn bubbleUp(self: *PriorityQueue, index: usize) void {
        var current_index = index;
        while (current_index > 0) {
            const parent_index = (current_index - 1) / 2;

            const parent_node = self.nodes[parent_index] orelse break;
            const current_node = self.nodes[current_index] orelse break;

            if (parent_node.frequency <= current_node.frequency) {
                break;
            }

            self.nodes[parent_index] = current_node;
            self.nodes[current_index] = parent_node;

            current_index = parent_index;
        }
    }

    pub fn remove(self: *PriorityQueue) !?*Node {
        if (self.len == 0) return null;

        const root = self.nodes[0];
        self.nodes[0] = self.nodes[self.len - 1];
        self.len -= 1;

        if (self.len > 0) {
            self.bubbleDown(0);
        }

        return root;
    }

    fn bubbleDown(self: *PriorityQueue, index: usize) void {
        var current_index = index;
        const len = self.len;

        while (true) {
            var smallest = current_index;
            // In a binary heap implemented using an array, we use a specific formula to calculate the indices of child nodes:
            //     0
            //   /   \
            //  1     2
            // / \   / \
            //3   4 5   6
            // When represented as an array: [0, 1, 2, 3, 4, 5, 6]
            // For node at index 0:
            // Left child: 2 * 0 + 1 = 1
            // Right child: 2 * 0 + 2 = 2, etc.
            const left_child = 2 * current_index + 1;
            const right_child = 2 * current_index + 2;

            // Check if left child is smaller than current smallest
            if (left_child < len) {
                if (self.nodes[left_child]) |left| {
                    if (self.nodes[smallest]) |smallest_node| {
                        if (left.frequency < smallest_node.frequency) {
                            smallest = left_child;
                        }
                    }
                }
            }

            // Check if right child is smaller than current smallest
            if (right_child < len) {
                if (self.nodes[right_child]) |right| {
                    if (self.nodes[smallest]) |smallest_node| {
                        if (right.frequency < smallest_node.frequency) {
                            smallest = right_child;
                        }
                    }
                }
            }
            // If smallest is still the current index, we're done
            if (smallest == current_index) {
                break;
            }

            // Swap current node with the smallest child
            const temp = self.nodes[current_index];
            self.nodes[current_index] = self.nodes[smallest];
            self.nodes[smallest] = temp;

            // Move down to the child we swapped with
            current_index = smallest;
        }
    }
};

pub fn printTree(node: *Node, depth: usize) void {
    // Print indentation
    for (0..depth * 2) |_| {
        std.debug.print(" ", .{});
    }

    // Check if it's a leaf node or an internal node
    if (node.left == null and node.right == null) {
        // Leaf node
        std.debug.print("Leaf: ({c}:{})\n", .{ node.character, node.frequency });
    } else {
        // Internal node
        std.debug.print("Internal: ({})\n", .{node.frequency});

        if (node.left) |left| {
            for (0..(depth + 1) * 2) |_| std.debug.print(" ", .{});
            std.debug.print("Left: ", .{});
            printTree(left, depth + 2);
        }

        if (node.right) |right| {
            for (0..(depth + 1) * 2) |_| std.debug.print(" ", .{});
            std.debug.print("Right: ", .{});
            printTree(right, depth + 2);
        }

        // Print merge information
        for (0..(depth + 1) * 2) |_| std.debug.print(" ", .{});
        std.debug.print("Merged: ({c}:{}) + ({c}:{}) = ({})\n", .{
            node.left.?.character,  node.left.?.frequency,
            node.right.?.character, node.right.?.frequency,
            node.frequency,
        });
    }
}

pub fn freeNode(allocator: std.mem.Allocator, node: *Node) void {
    if (node.left) |left| freeNode(allocator, left);
    if (node.right) |right| freeNode(allocator, right);
    allocator.destroy(node);
}

fn verifyTreeStructure(node: *Node) !void {
    if (node.left) |left| {
        try testing.expect(left.frequency <= node.frequency);
        try verifyTreeStructure(left);
    }
    if (node.right) |right| {
        try testing.expect(right.frequency <= node.frequency);
        try verifyTreeStructure(right);
    }
}

test "Node initialization" {
    const allocator = testing.allocator;

    {
        const node = try Node.init(allocator, 'X', 69);
        defer allocator.destroy(node);

        try testing.expectEqual(@as(u8, 'X'), node.character);
        try testing.expectEqual(@as(usize, 69), node.frequency);
        try testing.expect(node.left == null);
        try testing.expect(node.right == null);
    }

    {
        const node = try Node.init(allocator, 0, 0);
        defer allocator.destroy(node);

        try testing.expectEqual(@as(u8, 0), node.character);
        try testing.expectEqual(@as(usize, 0), node.frequency);
    }

    {
        const node = try Node.init(allocator, 255, std.math.maxInt(usize));
        defer allocator.destroy(node);

        try testing.expectEqual(@as(u8, 255), node.character);
        try testing.expectEqual(std.math.maxInt(usize), node.frequency);
    }

    {
        const node1 = try Node.init(allocator, 'A', 1);
        defer allocator.destroy(node1);
        const node2 = try Node.init(allocator, 'B', 2);
        defer allocator.destroy(node2);

        try testing.expect(node1 != node2);
        try testing.expectEqual(@as(u8, 'A'), node1.character);
        try testing.expectEqual(@as(u8, 'B'), node2.character);
    }
}

test "PriorityQueue" {
    // Test initialization
    var pq = try PriorityQueue.init(testing.allocator, 5);
    defer pq.deinit();

    try testing.expectEqual(@as(usize, 5), pq.capacity);
    try testing.expectEqual(@as(usize, 0), pq.len);

    // Test insertion
    const node1 = try Node.init(testing.allocator, 'A', 10);
    defer testing.allocator.destroy(node1);

    try pq.insert(node1);
    try testing.expectEqual(@as(usize, 1), pq.len);
    try testing.expectEqual(node1, pq.nodes[0].?);

    // Test multiple insertions
    const node2 = try Node.init(testing.allocator, 'B', 20);
    defer testing.allocator.destroy(node2);

    const node3 = try Node.init(testing.allocator, 'C', 30);
    defer testing.allocator.destroy(node3);

    try pq.insert(node2);
    try pq.insert(node3);

    try testing.expectEqual(@as(usize, 3), pq.len);
    try testing.expectEqual(node1, pq.nodes[0].?);
    try testing.expectEqual(node2, pq.nodes[1].?);
    try testing.expectEqual(node3, pq.nodes[2].?);

    // Test resizing
    const node4 = try Node.init(testing.allocator, 'D', 40);
    defer testing.allocator.destroy(node4);

    const node5 = try Node.init(testing.allocator, 'E', 50);
    defer testing.allocator.destroy(node5);

    const node6 = try Node.init(testing.allocator, 'F', 60);
    defer testing.allocator.destroy(node6);

    try pq.insert(node4);
    try pq.insert(node5);
    try pq.insert(node6);

    try testing.expectEqual(@as(usize, 6), pq.len);
    try testing.expectEqual(@as(usize, 10), pq.capacity);
    try testing.expectEqual(node6, pq.nodes[5].?);
}

test "PriorityQueue bubbleUp" {
    var pq = try PriorityQueue.init(testing.allocator, 10);
    defer pq.deinit();

    const nodeA = try Node.init(testing.allocator, 'A', 50);
    defer testing.allocator.destroy(nodeA);

    const nodeB = try Node.init(testing.allocator, 'B', 30);
    defer testing.allocator.destroy(nodeB);

    const nodeC = try Node.init(testing.allocator, 'C', 10);
    defer testing.allocator.destroy(nodeC);

    const nodeD = try Node.init(testing.allocator, 'D', 60);
    defer testing.allocator.destroy(nodeD);

    const nodeE = try Node.init(testing.allocator, 'E', 20);
    defer testing.allocator.destroy(nodeE);

    // Test case 1: Bubble up from bottom
    try pq.insert(nodeA);
    try pq.insert(nodeB);
    try pq.insert(nodeC);
    try testing.expectEqual(@as(u8, 'C'), pq.nodes[0].?.character);

    // Test case 2: No bubble up needed
    try pq.insert(nodeD);
    try testing.expectEqual(@as(u8, 'C'), pq.nodes[0].?.character);

    // Test case 3: Partial bubble up
    try pq.insert(nodeE);
    try testing.expectEqual(@as(u8, 'C'), pq.nodes[0].?.character);
    try testing.expectEqual(@as(u8, 'E'), pq.nodes[1].?.character);
}

test "PriorityQueue remove" {
    var pq = try PriorityQueue.init(testing.allocator, 10);
    defer pq.deinit();

    // Test case 1: Remove from empty queue
    try testing.expectEqual(@as(?*Node, null), try pq.remove());

    // Test case 2: Remove single element
    const nodeA = try Node.init(testing.allocator, 'A', 10);
    try pq.insert(nodeA);
    const removed1 = (try pq.remove()) orelse return error.UnexpectedNull;
    defer testing.allocator.destroy(removed1);
    try testing.expectEqual(@as(u8, 'A'), removed1.character);
    try testing.expectEqual(@as(usize, 0), pq.len);

    // Test case 3: Remove with reordering
    try pq.insert(try Node.init(testing.allocator, 'B', 20));
    try pq.insert(try Node.init(testing.allocator, 'C', 15));
    try pq.insert(try Node.init(testing.allocator, 'D', 25));

    const removed2 = (try pq.remove()) orelse return error.UnexpectedNull;
    defer testing.allocator.destroy(removed2);
    try testing.expectEqual(@as(u8, 'C'), removed2.character);
    try testing.expectEqual(@as(usize, 2), pq.len);

    const removed3 = (try pq.remove()) orelse return error.UnexpectedNull;
    defer testing.allocator.destroy(removed3);
    try testing.expectEqual(@as(u8, 'B'), removed3.character);

    // Clean up remaining nodes
    while (try pq.remove()) |node| {
        testing.allocator.destroy(node);
    }
}

test "buildHuffmanTree" {
    const allocator = testing.allocator;

    var freq_map = std.AutoHashMap(u8, usize).init(allocator);
    defer freq_map.deinit();

    try freq_map.put('a', 5);
    try freq_map.put('b', 9);
    try freq_map.put('c', 12);
    try freq_map.put('d', 13);
    try freq_map.put('e', 16);
    try freq_map.put('f', 45);

    const root = try PriorityQueue.buildTree(allocator, freq_map);
    defer freeNode(allocator, root);

    std.debug.print("Huffman Tree:\n", .{});
    printTree(root, 0);

    // Verify root
    try testing.expectEqual(@as(usize, 100), root.frequency);
    try testing.expectEqual(@as(u8, 0), root.character);

    // Verify left child (should be 'f' with frequency 45)
    try testing.expect(root.left != null);
    if (root.left) |left| {
        try testing.expectEqual(@as(usize, 45), left.frequency);
        try testing.expectEqual(@as(u8, 'f'), left.character);
    }

    // Verify right child (should be internal node with frequency 55)
    try testing.expect(root.right != null);
    if (root.right) |right| {
        try testing.expectEqual(@as(usize, 55), right.frequency);
        try testing.expectEqual(@as(u8, 0), right.character); // Internal node

        // Verify right.left (should be internal node with frequency 25)
        if (right.left) |right_left| {
            try testing.expectEqual(@as(usize, 25), right_left.frequency);
        } else return error.UnexpectedNull;

        // Verify right.right (should be internal node with frequency 30)
        if (right.right) |right_right| {
            try testing.expectEqual(@as(usize, 30), right_right.frequency);
        } else return error.UnexpectedNull;
    }
}
