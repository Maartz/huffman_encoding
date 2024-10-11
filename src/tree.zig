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

    pub fn bubbleDown(self: *PriorityQueue, index: usize) void {
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

test "PriorityQueue remove" {
    var pq = try PriorityQueue.init(testing.allocator, 10);
    defer pq.deinit();

    // Helper function to create nodes
    const createNode = struct {
        fn func(allocator: std.mem.Allocator, char: u8, freq: usize) !*Node {
            const node = try allocator.create(Node);
            node.* = Node.init(char, freq);
            return node;
        }
    }.func;

    // Test case 1: Remove from empty queue
    try testing.expectEqual(@as(?*Node, null), try pq.remove());

    // Test case 2: Remove single element
    try pq.insert(try createNode(testing.allocator, 'A', 10));
    const removed1 = (try pq.remove()) orelse return error.UnexpectedNull;
    defer testing.allocator.destroy(removed1);
    try testing.expectEqual(@as(u8, 'A'), removed1.character);
    try testing.expectEqual(@as(usize, 0), pq.len);

    // Test case 3: Remove with reordering
    try pq.insert(try createNode(testing.allocator, 'B', 20));
    try pq.insert(try createNode(testing.allocator, 'C', 15));
    try pq.insert(try createNode(testing.allocator, 'D', 25));

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
