const std = @import("std");
const polystate = @import("polystate");
const Witness = polystate.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const generic = @import("generic.zig");
const Window = glfw.Window;

comptime {
    const fsm_state_map = polystate.collect_fsm_state(20, Atm(Ready));
    const avl = fsm_state_map.avl;
    for (0..avl.len) |i| {
        _ = i;
    }
}

pub fn main() anyerror!void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const window = try generic.init_zgui(gpa, "ATM");
    defer generic.deinit_zgui(window);

    var ctx = Context.init(window);
    const StateReady = Atm(Ready);

    var graph = polystate.Graph.init;
    graph.generate(gpa, StateReady);

    std.debug.print("{}\n", .{graph});

    const Runner = polystate.Runner(20, false, StateReady);
    var curr_id: ?Runner.StateId = Runner.fsm_state_to_state_id(StateReady);
    while (curr_id) |id| {
        generic.clear_and_init(window);
        defer {
            zgui.backend.draw();
            window.swapBuffers();
        }
        curr_id = Runner.run_conthandler(id, &ctx);
    }
}

pub const Context = struct {
    pin: [4]u8 = .{ 1, 2, 3, 4 },
    tmpPin: [4:0]u8 = .{ 0, 0, 0, 0 },
    amount: usize = 10_0000,
    take_amount: i32 = 0,
    window: *Window,
    //
    are_you_sure: generic.AreYouSureData = .{},

    pub fn init(win: *Window) @This() {
        return .{ .window = win };
    }
};

pub fn Atm(Current: type) type {
    return polystate.FSM("Atm", Context, null, Current);
}

pub fn AreYouSure(yes: type, no: type) type {
    return generic.AreYouSure(Atm, Context, generic.zgui_are_you_sure_genMsg, yes, no);
}

pub const Ready = union(enum) {
    insert_card: Atm(CheckPin(Session, CheckPin(Session, CheckPin(Session, Ready)))),
    exit: Atm(AreYouSure(AreYouSure(polystate.Exit, Ready), Ready)),

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
        const window = ctx.window;
        if (window.shouldClose() or
            window.getKey(.q) == .press or
            window.getKey(.escape) == .press)
            return .{ .next = .exit };

        _ = zgui.begin("ready", .{ .flags = .{ .no_collapse = true, .no_move = true, .no_resize = true } });
        defer zgui.end();
        if (zgui.button("Isnert card", .{})) return .{ .next = .insert_card };
        if (zgui.button("Exit!", .{})) return .{ .next = .exit };
        return .no_trasition;
    }
};

pub fn CheckPin(Success: type, Failed: type) type {
    return union(enum) {
        successed: Atm(Success),
        failed: Atm(Failed),

        pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
            _ = zgui.begin("CheckPin", .{ .flags = .{
                .no_collapse = true,

                .no_move = true,
                .no_resize = true,
            } });
            defer zgui.end();

            _ = zgui.inputText("pin", .{
                .buf = &ctx.tmpPin,
                .flags = .{ .password = true, .chars_decimal = true },
            });

            if (zgui.button("OK", .{})) {
                for (0..4) |i| ctx.tmpPin[i] -|= 48;

                if (std.mem.eql(u8, &ctx.tmpPin, &ctx.pin)) {
                    ctx.tmpPin = .{ 0, 0, 0, 0 };
                    ctx.take_amount = @divTrunc(@as(i32, @intCast(ctx.amount)), 2);
                    return .{ .next = .successed };
                } else {
                    ctx.tmpPin = .{ 0, 0, 0, 0 };
                    std.debug.print("Error Pin!! {d}\n", .{ctx.tmpPin});
                    return .{ .next = .failed };
                }
            }
            return .no_trasition;
        }
    };
}

pub const Session = union(enum) {
    eject_card: Atm(Ready),

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
        _ = zgui.begin("Session", .{ .flags = .{
            .no_collapse = true,
            .no_move = true,
            .no_resize = true,
        } });
        defer zgui.end();

        zgui.text("amount: {d}", .{ctx.amount});
        _ = zgui.sliderInt(
            "disponse value",
            .{ .v = &ctx.take_amount, .min = 0, .max = @intCast(ctx.amount) },
        );

        if (zgui.button("Disponse", .{})) {
            const dv: usize = @intCast(ctx.take_amount);

            if (ctx.amount >= dv) {
                ctx.amount -= dv;
                ctx.take_amount = @divTrunc(@as(i32, @intCast(ctx.amount)), 2);
            } else std.debug.print("insufficient balance\n", .{});
        }
        if (zgui.button("Eject card", .{})) return .{ .next = .eject_card };
        return .no_trasition;
    }
};
