const std = @import("std");
const polystate = @import("polystate");

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const StateA = Example(A);
    var graph = polystate.Graph.init;
    try graph.generate(gpa, StateA);

    std.debug.print("{}\n", .{graph});

    std.debug.print("----------------------------\n", .{});
    var ctx: Context = .{};
    StateA.handler_normal(&ctx);

    std.debug.print("ctx: {any}\n", .{ctx});
    std.debug.print("----------------------------\n", .{});
}

pub const Context = struct {
    counter_a: i64 = 0,
    counter_b: i64 = 0,
    buf: [10]u8 = @splat(0),
};

///Example
pub fn Example(Current: type) type {
    return polystate.FSM(0, Context, enter_fn, Current);
}

fn enter_fn(
    ctx: *Context,
    Curr: type,
) void {
    std.debug.print("{st} ", .{@typeName(Curr)});
    std.debug.print("ctx: {any}\n", .{ctx.*});
}

pub const A = union(enum) {
    to_B: Example(B),
    exit: Example(YesOrNo(YesOrNo(polystate.Exit, B), B)),

    pub fn handler(ctx: *Context) @This() {
        if (ctx.counter_a > 30) return .exit;
        ctx.counter_a += 1;
        return .to_B;
    }
};

pub const B = union(enum) {
    to_A: Example(A),

    pub fn handler(ctx: *Context) @This() {
        ctx.counter_b += 1;
        return .to_A;
    }
};

pub fn YesOrNo(
    Yes: type,
    No: type,
) type {
    return union(enum) {
        yes: Example(Yes),
        no: Example(No),
        retry: Example(YesOrNo(Yes, No)),

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
