const std = @import("std");
const polystate = @import("polystate");

pub fn main() !void {
    //
    var gpa_instance = std.heap.DebugAllocator(.{}).init;
    const gpa = gpa_instance.allocator();

    const StateA = Example(A);

    var graph = polystate.Graph.init;

    graph.generate(gpa, StateA);

    std.debug.print("{}\n", .{graph});

    var ctx: Context = .{ .a = 0, .b = 0 };
    const Runner = polystate.Runner(20, false, StateA);
    var curr_id: ?Runner.StateId = Runner.fsm_state_to_state_id(StateA);
    while (curr_id) |id| {
        curr_id = Runner.run_conthandler(id, &ctx);
    }
}

pub const Context = struct {
    a: i32,
    b: i32,
};

pub fn Example(Current: type) type {
    return polystate.FSM("Cont", Context, enter_fn, Current);
}

fn enter_fn(
    ctx: *Context,
    Curr: type,
) void {
    std.debug.print("{st} ", .{@typeName(Curr)});
    std.debug.print("ctx: {any}\n", .{ctx.*});
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

pub fn Example1(Current: type) type {
    return polystate.FSM("Cont1", Context, null, Current);
}

pub const A1 = union(enum) {
    exit: Example1(polystate.Exit),
    to_B: Example1(B1),

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
        std.debug.print("a1: {d}\n", .{ctx.a});
        if (ctx.a > 5) return .{ .next = .exit };
        ctx.a += 1;
        return .{ .next = .to_B };
    }
};

pub const B1 = union(enum) {
    to_A: Example1(A1),

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
        std.debug.print("b1: {d}\n", .{ctx.b});
        ctx.b += 1;
        return .{ .next = .to_A };
    }
};
