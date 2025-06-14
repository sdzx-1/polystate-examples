const std = @import("std");
const polystate = @import("polystate");
const Witness = polystate.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const Window = glfw.Window;
const content_dir = @import("build_options").content_dir;

pub const AreYouSure = struct {
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

pub const Action = struct {
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

pub fn are_you_sureST(
    T: type,
    yes: polystate.sdzx(T),
    no: polystate.sdzx(T),
    GST: type,
    enter_fn: ?fn (polystate.sdzx(T), *const GST) void,
    ui_fn: fn (GST: type, *const GST) bool,
) type {
    return union(enum) {
        Yes: polystate.Witness(T, yes, GST, enter_fn),
        No: polystate.Witness(T, no, GST, enter_fn),

        pub fn handler(gst: *GST) void {
            switch (genMsg(gst)) {
                .Yes => |wit| wit.handler(gst),
                .No => |wit| wit.handler(gst),
            }
        }

        fn genMsg(gst: *const GST) @This() {
            if (ui_fn(GST, gst)) return .Yes else return .No;
        }
    };
}

pub fn actionST(
    T: type,
    mst: polystate.sdzx(T),
    jst: polystate.sdzx(T),
    GST: type,
    enter_fn: ?fn (polystate.sdzx(T), *const GST) void,
    ui_fn: fn (GST: type, comptime []const u8, *GST) void,
) type {
    return union(enum) {
        OK: polystate.Witness(T, jst, GST, enter_fn),

        pub fn handler(gst: *GST) void {
            const nst = switch (mst) {
                .Term => |v| @tagName(v),
                .Fun => |val| @tagName(val.fun),
            };
            switch (genMsg(nst, gst)) {
                .OK => |wit| wit.handler(gst),
            }
        }

        fn genMsg(comptime nst: []const u8, gst: *GST) @This() {
            ui_fn(GST, nst, gst);
            return .OK;
        }
    };
}

pub fn zgui_are_you_sure_genMsg(GST: type, gst: *GST) bool {
    const window = gst.window;
    var buf: [360]u8 = @splat(0);
    while (true) {
        clear_and_init(window);
        defer {
            zgui.backend.draw();
            window.swapBuffers();
        }

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
            gst.are_you_sure.color[0],
            gst.are_you_sure.color[1],
            gst.are_you_sure.color[2],
            1,
        } });
        defer zgui.popStyleColor(.{});

        zgui.pushStrId("are_you_sure yes");
        defer zgui.popId();
        if (zgui.button(&gst.are_you_sure.yes, .{})) {
            return true;
        }

        zgui.pushStrId("are_you_sure no");
        defer zgui.popId();
        if (zgui.button(&gst.are_you_sure.no, .{})) {
            return false;
        }

        if (window.getKey(.y) == .press) return true;
        if (window.getKey(.n) == .press) return false;
    }
}
pub fn zgui_action_genMsg(GST: type, comptime nst: []const u8, gst: *GST) void {
    const window = gst.window;
    var buf: [30]u8 = @splat(0);
    while (true) {
        clear_and_init(window);
        defer {
            zgui.backend.draw();
            window.swapBuffers();
        }

        const str = std.fmt.bufPrintZ(&buf, "action({s})", .{nst}) catch unreachable;
        _ = zgui.begin(str, .{ .flags = .{
            .no_collapse = true,
            .no_move = true,
            .no_resize = true,
        } });

        defer zgui.end();
        @field(gst, nst).zgui_render();

        zgui.pushStyleColor4f(.{ .idx = .button, .c = .{
            gst.action.color[0],
            gst.action.color[1],
            gst.action.color[2],
            1,
        } });
        defer zgui.popStyleColor(.{});

        zgui.pushStrId("action ok");
        defer zgui.popId();
        if (zgui.button(&gst.action.ok, .{})) {
            return;
        }
    }
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
