const std = @import("std");
const polystate = @import("polystate");

const ContR = polystate.ContR;

pub fn main() !void {
    //
    var gpa_instance = std.heap.DebugAllocator(.{}).init;
    const gpa = gpa_instance.allocator();

    var graph = polystate.Graph.init;

    try graph.generate(gpa, Example);

    std.debug.print("{}\n", .{graph});

    //
    var gst: Example.GST = .{ .a = 0, .b = 0 };
    const wit = Example.Wit(Example.a){};
    var next = wit.conthandler();
    var exit: bool = false;
    while (!exit) {
        switch (next(&gst)) {
            .Exit => exit = true,
            .Wait => {},
            .Next => |fun| next = fun,
        }
    }
}

const Example = enum {
    exit,
    a,
    b,

    pub const GST = struct {
        a: i32,
        b: i32,
    };

    pub const exitST = union(enum) {
        pub fn conthandler(gst: *GST) ContR(GST) {
            std.debug.print("exit\n", .{});
            std.debug.print("gst: {any}\n", .{gst});
            return .Exit;
        }
    };

    pub const aST = union(enum) {
        Exit: Wit(Example.exit),
        ToB: Wit(Example.b),

        pub fn conthandler(gst: *GST) ContR(GST) {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .Exit => |wit| {
                        return .{ .Next = wit.conthandler() };
                    },
                    .ToB => |wit| {
                        gst.a += 1;
                        return .{ .Next = wit.conthandler() };
                    },
                }
            }
            return .Wait;
        }

        fn genMsg(gst: *GST) ?@This() {
            std.debug.print("a: {d}\n", .{gst.a});
            if (gst.a > 5) return .Exit;
            return .ToB;
        }
    };

    pub const bST = union(enum) {
        ToA: Wit(Example.a),

        pub fn conthandler(gst: *GST) ContR(GST) {
            if (genMsg(gst)) |msg| {
                switch (msg) {
                    .ToA => |wit| {
                        gst.b += 1;
                        return .{ .Next = wit.conthandler() };
                    },
                }
            }
            return .Wait;
        }

        fn genMsg(gst: *GST) ?@This() {
            std.debug.print("b: {d}\n", .{gst.b});
            return .ToA;
        }
    };

    pub fn Wit(val: anytype) type {
        return polystate.Witness(@This(), polystate.val_to_sdzx(@This(), val), GST, null);
    }
};
