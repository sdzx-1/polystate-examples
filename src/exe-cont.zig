const std = @import("std");
const polystate = @import("polystate");
const ps = @import("polystate");

pub fn main() !void {
    //
    var gpa_instance = std.heap.DebugAllocator(.{}).init;
    const gpa = gpa_instance.allocator();

    const StateA = Example(.next, A);

    var graph = polystate.Graph.init;

    graph.generate(gpa, StateA);

    std.debug.print("{}\n", .{graph});

    var ctx: Context = .{ .a = 0, .b = 0 };
    const Runner = polystate.Runner(20, true, StateA);
    var curr_id: ?Runner.StateId = Runner.state_to_id(A);
    while (curr_id) |id| {
        curr_id = Runner.run_handler(id, &ctx);
        std.debug.print("suspended!\n", .{});
    }
}

pub const Context = struct {
    a: i32,
    b: i32,
};

pub fn Example(meth: ps.Method, Current: type) type {
    return ps.FSM("Cont", .suspendable, Context, enter_fn, meth, Current);
}

fn enter_fn(
    ctx: *Context,
    Curr: type,
) void {
    std.debug.print("{st} ", .{@typeName(Curr)});
    std.debug.print("ctx: {any}\n", .{ctx.*});
}

pub const A = union(enum) {
    // zig fmt: off
    exit : Example(.current, ps.Exit),
    to_B : Example(.next   , B),
    to_B1: Example(.current, B),
    // zig fmt: on

    pub fn handler(ctx: *Context) @This() {
        std.debug.print("a: {d}\n", .{ctx.a});
        if (ctx.a > 5) return .exit;
        ctx.a += 1;
        if (@mod(ctx.a, 2) == 0) return .to_B1;
        return .to_B;
    }
};

pub const B = union(enum) {
    to_A: Example(.next, A),

    pub fn handler(ctx: *Context) @This() {
        std.debug.print("b: {d}\n", .{ctx.b});
        ctx.b += 1;
        return .to_A;
    }
};

pub fn Example1(Current: type) type {
    return ps.FSM("Cont1", .no_suspendable, Context, enter_fn, {}, Current);
}

pub const A1 = union(enum) {
    // zig fmt: off
    exit : Example1(ps.Exit),
    to_B : Example1(B1),
    to_B1: Example1(B1),
    // zig fmt: on

    pub fn handler(ctx: *Context) @This() {
        std.debug.print("a: {d}\n", .{ctx.a});
        if (ctx.a > 5) return .exit;
        ctx.a += 1;
        if (@mod(ctx.a, 2) == 0) return .to_B1;
        return .to_B;
    }
};

pub const B1 = union(enum) {
    to_A: Example1(A1),

    pub fn handler(ctx: *Context) @This() {
        std.debug.print("b: {d}\n", .{ctx.b});
        ctx.b += 1;
        return .to_A;
    }
};
