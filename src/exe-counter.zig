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
    buf: [10]u8 = @splat(0),
};

///Example
const Example = enum {
    exit,
    a,
    b,
    yes_or_no,

    fn enter_fn(
        val: polystate.sdzx(Example),
        gst: *const GST,
    ) void {
        std.debug.print("{} ", .{val});
        std.debug.print("gst: {any}\n", .{gst.*});
    }

    pub fn Wit(val: anytype) type {
        return polystate.Witness(@This(), GST, enter_fn, polystate.val_to_sdzx(@This(), val));
    }

    pub const exitST = union(enum) {
        pub fn handler(ist: *GST) void {
            std.debug.print("exit\n", .{});
            std.debug.print("st: {any}\n", .{ist.*});
        }
    };
    pub const aST = a_st;
    pub const bST = b_st;

    pub fn yes_or_noST(yes: polystate.sdzx(@This()), no: polystate.sdzx(@This())) type {
        return yes_or_no_st(@This(), GST, yes, no);
    }
};

pub const a_st = union(enum) {
    AddOneThenToB: Example.Wit(Example.b),
    Exit: Example.Wit(.{ Example.yes_or_no, .{ Example.yes_or_no, Example.exit, Example.a }, Example.a }),

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

pub fn yes_or_no_st(
    FST: type,
    GST1: type,
    yes: polystate.sdzx(FST),
    no: polystate.sdzx(FST),
) type {
    return union(enum) {
        Yes: Wit(yes),
        No: Wit(no),
        Retry: Wit(polystate.sdzx(FST).C(FST.yes_or_no, &.{ yes, no })),

        fn Wit(val: polystate.sdzx(FST)) type {
            return polystate.Witness(FST, GST1, null, val);
        }

        pub fn handler(gst: *GST1) void {
            switch (genMsg(gst)) {
                .Yes => |wit| wit.handler(gst),
                .No => |wit| wit.handler(gst),
                .Retry => |wit| wit.handler(gst),
            }
        }

        const stdIn = std.io.getStdIn().reader();

        fn genMsg(gst: *GST) @This() {
            std.debug.print(
                \\Yes Or No:
                \\y={}, n={}
                \\
            ,
                .{ yes, no },
            );

            const st = stdIn.readUntilDelimiter(&gst.buf, '\n') catch |err| {
                std.debug.print("Input error: {any}, retry\n", .{err});
                return .Retry;
            };

            if (std.mem.eql(u8, st, "y")) {
                return .Yes;
            } else if (std.mem.eql(u8, st, "n")) {
                return .No;
            } else {
                std.debug.print("Error input: {s}\n", .{st});
                return .Retry;
            }
        }
    };
}
