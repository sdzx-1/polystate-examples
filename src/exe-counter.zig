const std = @import("std");
const polystate = @import("polystate");

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    var graph = polystate.Graph.init;
    try graph.generate(gpa, Example);

    std.debug.print("{}\n", .{graph});

    std.debug.print("----------------------------\n", .{});
    var st: GST = .{};
    const wa = Example.Wit(Example.a){};
    wa.handler_normal(&st);
    std.debug.print("----------------------------\n", .{});
}

pub const GST = struct {
    counter_a: i64 = 0,
    counter_b: i64 = 0,
};

///Example
const Example = enum {
    exit,
    a,
    b,
    select,

    fn prinet_enter_state(
        val: polystate.sdzx(Example),
        gst: *const GST,
    ) void {
        std.debug.print("{} ", .{val});
        std.debug.print("gst: {any}\n", .{gst.*});
    }

    pub fn Wit(val: anytype) type {
        return polystate.Witness(@This(), GST, prinet_enter_state, polystate.val_to_sdzx(@This(), val));
    }

    pub const exitST = union(enum) {
        pub fn handler(ist: *GST) void {
            std.debug.print("exit\n", .{});
            std.debug.print("st: {any}\n", .{ist.*});
        }
    };
    pub const bST = b_st;
    pub const aST = a_st;
    pub fn selectST(sa: polystate.sdzx(@This()), sb: polystate.sdzx(@This())) type {
        return select_st(@This(), .select, sa, sb, GST);
    }
};

pub const a_st = union(enum) {
    AddOneThenToB: Example.Wit(Example.b),
    Exit: Example.Wit(.{ Example.select, .{ Example.select, Example.exit, Example.a }, Example.a }),

    pub fn handler(ist: *GST) void {
        switch (genMsg(ist)) {
            .AddOneThenToB => |wit| {
                ist.counter_a += 1;
                wit.handler(ist);
            },
            .Exit => |wit| wit.handler(ist),
        }
    }

    fn genMsg(ist: *GST) @This() {
        if (ist.counter_a > 3) return .Exit;
        return .AddOneThenToB;
    }
};

pub const b_st = union(enum) {
    AddOneThenToA: Example.Wit(Example.a),

    pub fn handler(ist: *GST) void {
        switch (genMsg()) {
            .AddOneThenToA => |wit| {
                ist.counter_b += 1;
                wit.handler(ist);
            },
        }
    }

    fn genMsg() @This() {
        return .AddOneThenToA;
    }
};

pub fn select_st(
    T: type,
    current_st: T,
    a: polystate.sdzx(T),
    b: polystate.sdzx(T),
    State: type,
) type {
    return union(enum) {
        SelectA: RWit(a),
        SelectB: RWit(b),
        Retry: RWit(polystate.sdzx(T).C(current_st, &.{ a, b })),

        fn RWit(val: polystate.sdzx(T)) type {
            return polystate.Witness(T, State, null, val);
        }

        pub fn handler(ist: *State) void {
            switch (genMsg()) {
                .SelectA => |wit| wit.handler(ist),
                .SelectB => |wit| wit.handler(ist),
                .Retry => |wit| wit.handler(ist),
            }
        }

        const stdIn = std.io.getStdIn().reader();
        var buf: [10]u8 = @splat(0);

        fn genMsg() @This() {
            std.debug.print(
                \\Input your select:
                \\y={}, n={}
                \\
            ,
                .{ a, b },
            );

            const st = stdIn.readUntilDelimiter(&buf, '\n') catch |err| {
                std.debug.print("Input error: {any}, retry\n", .{err});
                return .Retry;
            };

            if (std.mem.eql(u8, st, "y")) {
                return .SelectA;
            } else if (std.mem.eql(u8, st, "n")) {
                return .SelectB;
            } else {
                std.debug.print(
                    \\Error input: {s}
                    \\You cant input: y={}, n={}
                    \\
                , .{ st, a, b });
                return .Retry;
            }
        }
    };
}
