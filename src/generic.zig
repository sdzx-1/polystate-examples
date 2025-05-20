const std = @import("std");
const typedFsm = @import("typed_fsm");
const Witness = typedFsm.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;
const Window = glfw.Window;
const content_dir = @import("build_options").content_dir;

pub fn actionST(
    T: type,
    st: typedFsm.sdzx(T),
    GST: type,
    enter_fn: ?fn (typedFsm.sdzx(T), *const GST) void,
) type {
    return union(enum) {
        OK: typedFsm.Witness(T, st, GST, enter_fn),

        pub fn handler(gst: *GST) void {
            switch (genMsg(gst)) {
                .OK => |wit| wit.handler(gst),
            }
        }

        fn genMsg(gst: *GST) @This() {
            const window = gst.window;
            var buf: [30]u8 = @splat(0);
            while (true) {
                clear_and_init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                const nst = switch (st) {
                    .Term => |v| @tagName(v),
                    .Fun => |val| @tagName(val.fun),
                };
                const str = std.fmt.bufPrintZ(&buf, "action({s})", .{nst}) catch unreachable;
                _ = zgui.begin(str, .{ .flags = .{
                    .no_collapse = true,
                    .no_move = true,
                    .no_resize = true,
                } });

                defer zgui.end();
                @field(gst, nst).render();

                zgui.pushStyleColor4f(.{ .idx = .button, .c = .{
                    gst.action.color[0],
                    gst.action.color[1],
                    gst.action.color[2],
                    1,
                } });
                defer zgui.popStyleColor(.{});
                if (zgui.button(&gst.action.ok, .{})) {
                    return .OK;
                }
            }
        }
    };
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

    const window = try glfw.Window.create(1000, 800, window_title, null);

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
