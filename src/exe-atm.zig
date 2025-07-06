const std = @import("std");
const ps = @import("polystate");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const generic = @import("generic.zig");
const Window = glfw.Window;
const Adler32 = std.hash.Adler32;

pub fn main() anyerror!void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const window = try generic.init_zgui(gpa, "ATM");
    defer generic.deinit_zgui(window);

    var ctx = Context.init(window);
    const StateReady = Atm(.next, Ready);

    var graph = ps.Graph.init;
    graph.generate(gpa, StateReady);

    const dot_file = try std.fs.cwd().createFile("t.dot", .{});
    try graph.print_graphviz(dot_file.writer());

    const Runner = ps.Runner(20, true, StateReady);
    var curr_id: ?Runner.StateId = Runner.idFromState(Ready);
    while (curr_id) |id| {
        generic.clear_and_init(window);
        defer {
            zgui.backend.draw();
            window.swapBuffers();
        }
        curr_id = Runner.runHandler(id, &ctx);
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

pub fn Atm(meth: ps.Method, Current: type) type {
    return ps.FSM("Atm", .suspendable, Context, null, meth, Current);
}

pub fn AreYouSure(yes: type, no: type) type {
    return generic.AreYouSure(Atm, yes, no);
}

pub const Ready = union(enum) {
    insert_card: Atm(.next, CheckPin(Session, CheckPin(Session, CheckPin(Session, Ready)))),
    exit: Atm(.next, AreYouSure(AreYouSure(ps.Exit, Ready), Ready)),
    no_trasition: Atm(.next, @This()),

    pub fn handler(ctx: *Context) @This() {
        const window = ctx.window;
        if (window.shouldClose() or
            window.getKey(.q) == .press or
            window.getKey(.escape) == .press)
            return .exit;

        _ = zgui.begin("ready", .{ .flags = .{ .no_collapse = true, .no_move = true, .no_resize = true } });
        defer zgui.end();
        if (zgui.button("Isnert card", .{})) return .insert_card;
        if (zgui.button("Exit!", .{})) return .exit;
        return .no_trasition;
    }
};

pub fn CheckPin(Success: type, Failed: type) type {
    return union(enum) {
        successed: Atm(.next, Success),
        failed: Atm(.next, Failed),
        no_trasition: Atm(.next, @This()),

        pub fn handler(ctx: *Context) @This() {
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
                    return .successed;
                } else {
                    ctx.tmpPin = .{ 0, 0, 0, 0 };
                    std.debug.print("Error Pin!! {d}\n", .{ctx.tmpPin});
                    return .failed;
                }
            }
            return .no_trasition;
        }
    };
}

pub const Session = union(enum) {
    eject_card: Atm(.next, Ready),
    no_trasition: Atm(.next, @This()),

    pub fn handler(ctx: *Context) @This() {
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
        if (zgui.button("Eject card", .{})) return .eject_card;
        return .no_trasition;
    }
};
