const std = @import("std");
const ps = @import("polystate");

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const StateA = Example(.next, A);
    var graph = try ps.Graph.initWithFsm(gpa, StateA, 20);

    const dot_file = try std.fs.cwd().createFile("t.dot", .{});
    try graph.generateDot(dot_file.writer());

    const mermaid_file = try std.fs.cwd().createFile("t.mmd", .{});
    try graph.generateMermaid(mermaid_file.writer());

    std.debug.print("----------------------------\n", .{});

    var ctx: Context = .{};
    const Runner = ps.Runner(20, true, StateA);
    var curr_id: ?Runner.StateId = Runner.idFromState(A);

    while (curr_id) |id| {
        curr_id = Runner.runHandler(id, &ctx);
    }

    std.debug.print("ctx: {any}\n", .{ctx});
    std.debug.print("----------------------------\n", .{});
}

pub const Context = struct {
    counter_a: i64 = 0,
    counter_b: i64 = 0,
    buf: [10]u8 = @splat(0),
};

///Example
pub fn Example(method: ps.Method, Current: type) type {
    return ps.FSM("Counter", .suspendable, Context, enter_fn, method, Current);
}

fn enter_fn(
    ctx: *Context,
    Curr: type,
) void {
    _ = ctx;
    _ = Curr;
    // std.debug.print("{st} ", .{@typeName(Curr)});
    // std.debug.print("ctx: {any}\n", .{ctx.*});
}

pub const A = union(enum) {
    to_B: Example(.next, B),
    exit: Example(.next, YesOrNo(Example, YesOrNo(Example, ps.Exit, B), B)),

    pub fn handler(ctx: *Context) @This() {
        if (ctx.counter_a > 30_000_000) return .exit;
        ctx.counter_a += 1;
        return .to_B;
    }
};

pub const B = union(enum) {
    to_A: Example(.next, A),

    pub fn handler(ctx: *Context) @This() {
        ctx.counter_b += 1;
        return .to_A;
    }
};

pub fn YesOrNo(
    FSM: fn (ps.Method, type) type,
    Yes: type,
    No: type,
) type {
    return union(enum) {
        // zig fmt: off
        yes  : FSM(.next, Yes),
        no   : FSM(.next, No),
        retry: FSM(.next, @This()), //YesOrNo(FSM, Yes, No)
        // zig fmt: on

        const stdIn = std.io.getStdIn().reader();
        pub fn handler(ctx: *Context) @This() {
            std.debug.print(
                \\Yes Or No:
                \\y={s}, n={s}
                \\
            ,
                .{ @typeName(Yes), @typeName(No) },
            );

            const st = stdIn.readUntilDelimiter(&ctx.buf, '\n') catch |err| {
                std.debug.print("Input error: {any}, retry\n", .{err});
                return .retry;
            };

            if (std.mem.eql(u8, st, "y")) {
                return .yes;
            } else if (std.mem.eql(u8, st, "n")) {
                return .no;
            } else {
                std.debug.print("Error input: {s}\n", .{st});
                return .retry;
            }
        }
    };
}
