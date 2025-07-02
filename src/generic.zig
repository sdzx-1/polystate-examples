const std = @import("std");
const ps = @import("polystate");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const Window = glfw.Window;
const content_dir = @import("build_options").content_dir;

pub const AreYouSureData = struct {
    yes: [20:0]u8 = blk: {
        var tmp: [20:0]u8 = @splat(0);
        @memcpy(tmp[0..3], "YES");
        break :blk tmp;
    },

    no: [20:0]u8 = blk: {
        var tmp: [20:0]u8 = @splat(0);
        @memcpy(tmp[0..2], "NO");
        break :blk tmp;
    },
    color: [3]f32 = .{ 0, 0.2, 0.4 },

    pub fn zgui_render(self: *@This()) void {
        _ = zgui.inputText("yes", .{ .buf = &self.yes });
        _ = zgui.inputText("no", .{ .buf = &self.no });
        _ = zgui.colorPicker3("color", .{ .col = &self.color });
    }
};

pub fn AreYouSure(
    FSM: fn (ps.Method, type) type,
    Yes: type,
    No: type,
) type {
    const Context = FSM(.current, ps.Exit).Context;
    return union(enum) {
        yes: FSM(.next, Yes),
        no: FSM(.next, No),
        no_trasition: FSM(.next, @This()),

        pub fn handler(ctx: *Context) @This() {
            if (zgui_are_you_sure_genMsg(Context, ctx)) |res| {
                if (res) return .yes else return .no;
            } else return .no_trasition;
        }

        pub fn zgui_render(ctx: *Context) void {
            ctx.are_you_sure.zgui_render();
        }
    };
}

pub fn zgui_are_you_sure_genMsg(Context: type, ctx: *Context) ?bool {
    const window = ctx.window;
    var buf: [360]u8 = @splat(0);
    const str = std.fmt.bufPrintZ(
        &buf,
        "are_you_sure",
        .{},
    ) catch unreachable;
    _ = zgui.begin(str, .{ .flags = .{
        .no_collapse = true,
        .no_move = true,
        .no_resize = true,
    } });

    defer zgui.end();

    zgui.pushStyleColor4f(.{ .idx = .button, .c = .{
        ctx.are_you_sure.color[0],
        ctx.are_you_sure.color[1],
        ctx.are_you_sure.color[2],
        1,
    } });
    defer zgui.popStyleColor(.{});

    zgui.pushStrId("are_you_sure yes");
    defer zgui.popId();
    if (zgui.button(&ctx.are_you_sure.yes, .{})) {
        return true;
    }

    zgui.pushStrId("are_you_sure no");
    defer zgui.popId();
    if (zgui.button(&ctx.are_you_sure.no, .{})) {
        return false;
    }

    if (window.getKey(.y) == .press) return true;
    if (window.getKey(.n) == .press) return false;

    return null;
}

pub const ActionData = struct {
    ok: [20:0]u8 = blk: {
        var tmp: [20:0]u8 = @splat(0);
        tmp[0] = 'O';
        tmp[1] = 'K';
        break :blk tmp;
    },
    color: [3]f32 = .{ 0, 0.2, 0.4 },

    pub fn zgui_render(self: *@This()) void {
        _ = zgui.inputText("title", .{
            .buf = &self.ok,
        });
        _ = zgui.colorPicker3("color", .{ .col = &self.color });
    }
};

pub fn Action(
    FSM: fn (ps.Method, type) type,
    mst: type, //Modify State
    jst: type, //Jump to State
) type {
    const Context = FSM(.next, ps.Exit).Context;
    return union(enum) {
        OK: FSM(.next, jst),
        no_trasition: FSM(.next, Action(FSM, mst, jst)),

        pub fn handler(ctx: *Context) @This() {
            if (zgui_action_genMsg(Context, mst, ctx)) return .OK;
            return .no_trasition;
        }

        pub fn zgui_render(ctx: *Context) void {
            ctx.action.zgui_render();
        }
    };
}

pub fn zgui_action_genMsg(Context: type, nst: type, ctx: *Context) bool {
    var buf: [500]u8 = @splat(0);
    const str = std.fmt.bufPrintZ(&buf, "action({s})", .{@typeName(nst)}) catch unreachable;
    _ = zgui.begin(str, .{ .flags = .{
        .no_collapse = true,
        .no_move = true,
        .no_resize = true,
    } });

    defer zgui.end();
    nst.zgui_render(ctx);

    zgui.pushStyleColor4f(.{ .idx = .button, .c = .{
        ctx.action.color[0],
        ctx.action.color[1],
        ctx.action.color[2],
        1,
    } });
    defer zgui.popStyleColor(.{});

    zgui.pushStrId("action ok");
    defer zgui.popId();
    if (zgui.button(&ctx.action.ok, .{})) {
        return true;
    }
    return false;
}

pub fn clear_and_init(window: *Window) void {
    glfw.pollEvents();
    gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.2, 0.2, 0, 1.0 });
    const fb_size = window.getFramebufferSize();
    zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));
    zgui.setNextWindowPos(.{ .x = 0, .y = 0 });
    zgui.setNextWindowSize(.{
        .w = @floatFromInt(fb_size[0]),
        .h = @floatFromInt(fb_size[1]),
    });
}

pub fn init_zgui(gpa: std.mem.Allocator, window_title: [:0]const u8) !*Window {
    try glfw.init();

    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    const gl_major = 4;
    const gl_minor = 0;

    glfw.windowHint(.context_version_major, gl_major);
    glfw.windowHint(.context_version_minor, gl_minor);
    glfw.windowHint(.opengl_profile, .opengl_core_profile);
    glfw.windowHint(.opengl_forward_compat, true);
    glfw.windowHint(.client_api, .opengl_api);
    glfw.windowHint(.doublebuffer, true);

    const window = try glfw.Window.create(1000, 900, window_title, null);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    zgui.init(gpa);

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };

    _ = zgui.io.addFontFromFileWithConfig(
        content_dir ++ "FiraMono.ttf",
        std.math.floor(22.0 * scale_factor),
        null,
        null,
    );

    zgui.getStyle().scaleAllSizes(scale_factor);
    zgui.backend.init(window);
    return window;
}
pub fn deinit_zgui(window: *Window) void {
    zgui.backend.deinit();
    zgui.deinit();
    window.destroy();
    glfw.terminate();
}
