const std = @import("std");
const polystate = @import("polystate");
const Witness = polystate.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const generic = @import("generic.zig");
const Window = glfw.Window;

pub fn main() anyerror!void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const window = try generic.init_zgui(gpa, "ATM");
    defer generic.deinit_zgui(window);

    var ist = GST.init(window);

    var graph = polystate.Graph.init;
    try graph.generate(gpa, Atm);

    std.debug.print("{}\n", .{graph});

    const wit = Atm.Wit(Atm.ready){};

    var next = wit.conthandler();
    var exit: bool = false;

    while (!exit) {
        generic.clear_and_init(window);
        defer {
            zgui.backend.draw();
            window.swapBuffers();
        }

        sw: switch (next(&ist)) {
            .Exit => exit = true,
            .Wait => {},
            .Next => |fun| next = fun,
            .Curr => |fun| {
                next = fun;
                continue :sw fun(&ist);
            },
        }
    }
}

pub const GST = struct {
    pin: [4]u8 = .{ 1, 2, 3, 4 },
    tmpPin: [4:0]u8 = .{ 0, 0, 0, 0 },
    amount: usize = 10_0000,
    window: *Window,
    //
    are_you_sure: generic.AreYouSure = .{},

    pub fn init(win: *Window) @This() {
        return .{ .window = win };
    }
};

const ContR = polystate.ContR(GST);

pub const Atm = enum {
    exit,
    ready,
    checkPin,
    session,
    are_you_sure,

    pub fn Wit(val: anytype) type {
        return polystate.Witness(@This(), GST, null, polystate.val_to_sdzx(@This(), val));
    }

    pub fn are_you_sureST(yes: polystate.sdzx(Atm), no: polystate.sdzx(Atm)) type {
        return generic.are_you_sureST(Atm, GST, null, generic.zgui_are_you_sure_genMsg, yes, no);
    }

    pub const exitST = union(enum) {
        pub fn conthandler(ist: *GST) ContR {
            std.debug.print("exit\n", .{});
            std.debug.print("st: {any}\n", .{ist.*});
            return .Exit;
        }
    };

    pub const readyST = union(enum) {
        InsertCard: Wit(.{ Atm.checkPin, Atm.session, .{ Atm.checkPin, Atm.session, .{ Atm.checkPin, Atm.session, Atm.ready } } }),
        Exit: Wit(.{ Atm.are_you_sure, Atm.exit, Atm.ready }),

        pub fn conthandler(ist: *GST) ContR {
            if (genMsg(ist.window)) |msg| {
                switch (msg) {
                    .Exit => |wit| return .{ .Next = wit.conthandler() },
                    .InsertCard => |wit| return .{ .Next = wit.conthandler() },
                }
            } else return .Wait;
        }

        fn genMsg(window: *Window) ?@This() {
            if (window.shouldClose() or
                window.getKey(.q) == .press or
                window.getKey(.escape) == .press)
                return .Exit;

            _ = zgui.begin("ready", .{ .flags = .{ .no_collapse = true, .no_move = true, .no_resize = true } });
            defer zgui.end();
            if (zgui.button("Isnert card", .{})) return .InsertCard;
            if (zgui.button("Exit!", .{})) return .Exit;
            return null;
        }
    };

    pub fn checkPinST(success: polystate.sdzx(Atm), failed: polystate.sdzx(Atm)) type {
        return union(enum) {
            Successed: polystate.Witness(Atm, GST, null, success),
            Failed: polystate.Witness(Atm, GST, null, failed),

            pub fn conthandler(ist: *GST) ContR {
                if (genMsg(&ist.tmpPin, &ist.pin)) |msg| {
                    switch (msg) {
                        .Successed => |wit| {
                            ist.tmpPin = .{ 0, 0, 0, 0 };
                            return .{ .Next = wit.conthandler() };
                        },
                        .Failed => |wit| {
                            ist.tmpPin = .{ 0, 0, 0, 0 };
                            return .{ .Next = wit.conthandler() };
                        },
                    }
                } else return .Wait;
            }

            fn genMsg(tmpPin: *[4:0]u8, pin: []const u8) ?@This() {
                _ = zgui.begin("CheckPin", .{ .flags = .{
                    .no_collapse = true,

                    .no_move = true,
                    .no_resize = true,
                } });
                defer zgui.end();

                _ = zgui.inputText("pin", .{
                    .buf = tmpPin,
                    .flags = .{ .password = true, .chars_decimal = true },
                });

                if (zgui.button("OK", .{})) {
                    for (0..4) |i| tmpPin[i] -|= 48;

                    if (std.mem.eql(u8, tmpPin, pin)) {
                        return .Successed;
                    } else {
                        return .Failed;
                    }
                }
                return null;
            }
        };
    }

    pub const sessionST = union(enum) {
        Disponse: struct { wit: Wit(Atm.session) = .{}, v: usize },
        EjectCard: Wit(Atm.ready),

        pub fn conthandler(ist: *GST) ContR {
            if (genMsg(ist.amount)) |msg| {
                switch (msg) {
                    .Disponse => |val| {
                        if (ist.amount >= val.v) {
                            ist.amount -= val.v;
                            return .{ .Next = val.wit.conthandler() };
                        } else {
                            std.debug.print("insufficient balance\n", .{});
                            return .{ .Next = val.wit.conthandler() };
                        }
                    },
                    .EjectCard => |wit| return .{ .Next = wit.conthandler() },
                }
            } else return .Wait;
        }

        fn genMsg(amount: usize) ?@This() {
            var dispVal: i32 = @divTrunc(@as(i32, @intCast(amount)), 2);

            _ = zgui.begin("Session", .{ .flags = .{
                .no_collapse = true,

                .no_move = true,
                .no_resize = true,
            } });
            defer zgui.end();

            zgui.text("amount: {d}", .{amount});
            _ = zgui.sliderInt(
                "disponse value",
                .{ .v = &dispVal, .min = 0, .max = @intCast(amount) },
            );

            if (zgui.button("Disponse", .{})) return .{ .Disponse = .{ .v = @intCast(dispVal) } };
            if (zgui.button("Eject card", .{})) return .EjectCard;
            return null;
        }
    };
};
