const std = @import("std");
const polystate = @import("polystate");

pub fn main() !void {
    //
    var gpa_instance = std.heap.DebugAllocator(.{}).init;
    const gpa = gpa_instance.allocator();

    const StateA = Example(A);

    var graph = polystate.Graph.init;

    try graph.generate(gpa, StateA);

    std.debug.print("{}\n", .{graph});

    var ctx: Context = .{ .a = 0, .b = 0 };
    var next = &StateA.conthandler;
    var exit: bool = false;

    while (!exit) {
        sw: switch (next(&ctx)) {
            .exit => exit = true,
            .no_trasition => {},
            .next => |fun| next = fun,
            .current => |fun| {
                next = fun;
                continue :sw fun(&ctx);
            },
        }
    }
}

pub const Context = struct {
    a: i32,
    b: i32,
};

pub fn Example(Current: type) type {
    return polystate.FSM(0, Context, null, Current);
}

pub const A = union(enum) {
    exit: Example(polystate.Exit),
    to_B: Example(B),

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
        std.debug.print("a: {d}\n", .{ctx.a});
        if (ctx.a > 5) return .{ .next = .exit };
        ctx.a += 1;
        return .{ .next = .to_B };
    }
};

pub const B = union(enum) {
    to_A: Example(A),

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
        std.debug.print("b: {d}\n", .{ctx.b});
        ctx.b += 1;
        return .{ .next = .to_A };
    }
};
