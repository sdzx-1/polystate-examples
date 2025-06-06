const std = @import("std");
const typedFsm = @import("typed_fsm");
const Witness = typedFsm.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const generic = @import("generic.zig");
const Window = glfw.Window;

pub fn main() anyerror!void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const window = try generic.init_zgui(gpa, "ATM");
    defer generic.deinit_zgui(window);

    var ist = Atm.State.init(window);

    var graph = typedFsm.Graph.init;
    try graph.generate(gpa, Atm);

    std.debug.print("{}\n", .{graph});

    const wa = Atm.EWit(.ready){};
    wa.handler_normal(&ist);
}

pub const Atm = enum {
    exit,
    ready,
    checkPin, // checkPin(session, checkPin(session, checkPin(session, ready)))
    session,
    are_you_sure,

    pub const State = struct {
        pin: [4]u8 = .{ 1, 2, 3, 4 },
        amount: usize = 10_0000,
        window: *Window,
        //
        are_you_sure: generic.AreYouSure = .{},

        pub fn init(win: *Window) @This() {
            return .{ .window = win };
        }
    };

    fn prinet_enter_state(
        val: typedFsm.sdzx(Atm),
        gst: *const Atm.State,
    ) void {
        std.debug.print("current_st :  {}\n", .{val});
        std.debug.print("current_gst: {any}\n", .{gst.*});
    }

    pub fn EWit(t: @This()) type {
        return typedFsm.Witness(@This(), typedFsm.val_to_sdzx(@This(), t), State, prinet_enter_state);
    }
    pub fn EWitFn(val: anytype) type {
        return typedFsm.Witness(@This(), typedFsm.val_to_sdzx(@This(), val), State, prinet_enter_state);
    }

    pub fn are_you_sureST(yes: typedFsm.sdzx(Atm), no: typedFsm.sdzx(Atm)) type {
        return generic.are_you_sureST(
            Atm,
            yes,
            no,
            State,
            prinet_enter_state,
            generic.zgui_are_you_sure_genMsg,
        );
    }

    pub const exitST = union(enum) {
        pub fn handler(ist: *State) void {
            std.debug.print("exit\n", .{});
            std.debug.print("st: {any}\n", .{ist.*});
        }
    };

    pub const readyST = union(enum) {
        InsertCard: EWitFn(.{ Atm.checkPin, Atm.session, .{ Atm.checkPin, Atm.session, .{ Atm.checkPin, Atm.session, Atm.ready } } }),
        Exit: EWitFn(.{ Atm.are_you_sure, Atm.exit, Atm.ready }),

        pub fn handler(ist: *State) void {
            switch (genMsg(ist.window)) {
                .Exit => |wit| wit.handler(ist),
                .InsertCard => |wit| wit.handler(ist),
            }
        }

        fn genMsg(window: *Window) @This() {
            while (true) {
                generic.clear_and_init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                if (window.shouldClose() or
                    window.getKey(.q) == .press or
                    window.getKey(.escape) == .press)
                    return .{ .Exit = .{} };

                {
                    _ = zgui.begin("ready", .{ .flags = .{
                        .no_collapse = true,

                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();
                    if (zgui.button("Isnert card", .{})) {
                        return .InsertCard;
                    }
                    if (zgui.button("Exit!", .{})) {
                        return .{ .Exit = .{} };
                    }
                }
            }
        }
    };

    pub fn checkPinST(success: typedFsm.sdzx(Atm), failed: typedFsm.sdzx(Atm)) type {
        return union(enum) {
            Successed: typedFsm.Witness(Atm, success, State, prinet_enter_state),
            Failed: typedFsm.Witness(Atm, failed, State, prinet_enter_state),

            pub fn handler(ist: *State) void {
                switch (genMsg(ist.window, &ist.pin)) {
                    .Successed => |wit| wit.handler(ist),
                    .Failed => |wit| wit.handler(ist),
                }
            }

            fn genMsg(window: *Window, pin: []const u8) @This() {
                var tmpPin: [4:0]u8 = .{ 0, 0, 0, 0 };
                while (true) {
                    generic.clear_and_init(window);
                    defer {
                        zgui.backend.draw();
                        window.swapBuffers();
                    }

                    {
                        _ = zgui.begin("CheckPin", .{ .flags = .{
                            .no_collapse = true,

                            .no_move = true,
                            .no_resize = true,
                        } });
                        defer zgui.end();

                        _ = zgui.inputText("pin", .{
                            .buf = &tmpPin,
                            .flags = .{ .password = true, .chars_decimal = true },
                        });

                        if (zgui.button("OK", .{})) {
                            for (0..4) |i| tmpPin[i] -|= 48;

                            if (std.mem.eql(u8, &tmpPin, pin)) {
                                return .Successed;
                            } else {
                                return .Failed;
                            }
                        }
                    }
                }
            }
        };
    }

    pub const sessionST = union(enum) {
        Disponse: struct { wit: EWit(.session) = .{}, v: usize },
        EjectCard: EWit(.ready),

        pub fn handler(ist: *State) void {
            switch (genMsg(ist.window, ist.amount)) {
                .Disponse => |val| {
                    if (ist.amount >= val.v) {
                        ist.amount -= val.v;
                        val.wit.handler(ist);
                    } else {
                        std.debug.print("insufficient balance\n", .{});
                        val.wit.handler(ist);
                    }
                },
                .EjectCard => |wit| wit.handler(ist),
            }
        }

        fn genMsg(window: *Window, amount: usize) @This() {
            var dispVal: i32 = @divTrunc(@as(i32, @intCast(amount)), 2);
            while (true) {
                generic.clear_and_init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                {
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

                    if (zgui.button("Disponse", .{})) {
                        return .{ .Disponse = .{ .v = @intCast(dispVal) } };
                    }

                    if (zgui.button("Eject card", .{})) {
                        return .EjectCard;
                    }
                }
            }
        }
    };
};
