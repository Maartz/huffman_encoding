const std = @import("std");
const testing = std.testing;

const Node = struct {
    character: u8,
    frequency: usize,
    left: ?*Node,
    right: ?*Node,

    pub fn init(char: u8, freq: usize) Node {
        return Node{
            .character = char,
            .frequency = freq,
            .left = null,
            .right = null,
        };
    }
};

const PriorityQueue = struct {
    nodes: []?*Node,
    len: usize,
    capacity: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !PriorityQueue {
        const nodes = try allocator.alloc(?*Node, capacity);
        for (nodes) |*node| {
            node.* = null;
        }
        return PriorityQueue{ .allocator = allocator, .capacity = capacity, .len = 0, .nodes = nodes };
    }

    pub fn deinit(self: *PriorityQueue) void {
        self.allocator.free(self.nodes);
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

    pub fn bubbleUp(self: *PriorityQueue, index: usize) void {
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
};

test "Node init" {
    const node = Node.init('X', 69);
    try testing.expectEqual('X', node.character);
    try testing.expectEqual(69, node.frequency);
}

test "PriorityQueue" {
    // Test initialization
    var pq = try PriorityQueue.init(testing.allocator, 5);
    defer pq.deinit();

    try testing.expectEqual(@as(usize, 5), pq.capacity);
    try testing.expectEqual(@as(usize, 0), pq.len);

    // Test insertion
    const node1 = try testing.allocator.create(Node);
    defer testing.allocator.destroy(node1);
    node1.* = Node.init('A', 10);

    try pq.insert(node1);
    try testing.expectEqual(@as(usize, 1), pq.len);
    try testing.expectEqual(node1, pq.nodes[0].?);

    // Test multiple insertions
    const node2 = try testing.allocator.create(Node);
    defer testing.allocator.destroy(node2);
    node2.* = Node.init('B', 20);

    const node3 = try testing.allocator.create(Node);
    defer testing.allocator.destroy(node3);
    node3.* = Node.init('C', 30);

    try pq.insert(node2);
    try pq.insert(node3);

    try testing.expectEqual(@as(usize, 3), pq.len);
    try testing.expectEqual(node1, pq.nodes[0].?);
    try testing.expectEqual(node2, pq.nodes[1].?);
    try testing.expectEqual(node3, pq.nodes[2].?);

    // Test resizing
    const node4 = try testing.allocator.create(Node);
    defer testing.allocator.destroy(node4);
    node4.* = Node.init('D', 40);

    const node5 = try testing.allocator.create(Node);
    defer testing.allocator.destroy(node5);
    node5.* = Node.init('E', 50);

    const node6 = try testing.allocator.create(Node);
    defer testing.allocator.destroy(node6);
    node6.* = Node.init('F', 60);

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

    const nodeA = try testing.allocator.create(Node);
    defer testing.allocator.destroy(nodeA);
    nodeA.* = Node.init('A', 50);

    const nodeB = try testing.allocator.create(Node);
    defer testing.allocator.destroy(nodeB);
    nodeB.* = Node.init('B', 30);

    const nodeC = try testing.allocator.create(Node);
    defer testing.allocator.destroy(nodeC);
    nodeC.* = Node.init('C', 10);

    const nodeD = try testing.allocator.create(Node);
    defer testing.allocator.destroy(nodeD);
    nodeD.* = Node.init('D', 60);

    const nodeE = try testing.allocator.create(Node);
    defer testing.allocator.destroy(nodeE);
    nodeE.* = Node.init('E', 20);

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
