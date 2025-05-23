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

    const window = try generic.init_zgui(gpa, "editor");
    defer generic.deinit_zgui(window);

    const str_buf = try gpa.allocSentinel(u8, 1 << 10, 0);
    defer gpa.free(str_buf);
    @memset(str_buf, 0);
    const start_str = "start!";

    for (start_str, 0..) |str, i| {
        str_buf[i] = str;
    }

    var gst = GST{ .window = window, .str_buf = str_buf };

    const mainWit = Editor.Wit(Editor.init){};
    mainWit.handler_normal(&gst);
}

const GST = struct {
    window: *Window,
    main: Main = .{},
    action: generic.Action = .{},
    str_buf: [:0]u8,
};

const Pos = struct { x: f32, y: f32 };

const Main = struct {
    exit: [2]f32 = .{ 0, 80 },
    print: [2]f32 = .{ 0, 120 },
    modify: [2]f32 = .{ 0, 160 },

    pub fn render(self: *@This()) void {
        _ = zgui.sliderFloat2("exit", .{ .v = &self.exit, .min = 0, .max = 1000 });
        _ = zgui.sliderFloat2("print", .{ .v = &self.print, .min = 0, .max = 1000 });
        _ = zgui.sliderFloat2("modify", .{ .v = &self.modify, .min = 0, .max = 1000 });

        zgui.setCursorPos(self.exit);
        zgui.text("exit", .{});

        zgui.setCursorPos(self.print);
        zgui.text("print", .{});

        zgui.setCursorPos(self.modify);
        zgui.text("modify", .{});
    }
};

const Editor = enum {
    exit,
    init,
    main,
    action,

    fn enter_fn(cst: typedFsm.sdzx(@This()), gst: *const GST) void {
        _ = gst;
        std.debug.print("cst: {}\n", .{cst});
    }

    pub fn Wit(val: anytype) type {
        return typedFsm.Witness(@This(), typedFsm.val_to_sdzx(Editor, val), GST, enter_fn);
    }

    pub fn actionST(mst: typedFsm.sdzx(Editor), jst: typedFsm.sdzx(Editor)) type {
        return generic.actionST(Editor, mst, jst, GST, enter_fn);
    }

    pub const exitST = union(enum) {
        pub fn handler(gst: *GST) void {
            std.debug.print("exit\n", .{});
            std.debug.print("gst: {any}\n", .{gst});
        }
    };

    pub const initST = union(enum) {
        GotoMain: Wit(Editor.main),
        Exit: Wit(Editor.exit),

        pub fn handler(gst: *GST) void {
            switch (genMsg(gst)) {
                .GotoMain => |wit| wit.handler(gst),
                .Exit => |wit| wit.handler(gst),
            }
        }

        fn genMsg(gst: *GST) @This() {
            const window = gst.window;
            while (true) {
                generic.clear_and_init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                if (window.shouldClose() or
                    window.getKey(.q) == .press or
                    window.getKey(.escape) == .press)
                    return .Exit;

                {
                    _ = zgui.begin("init", .{ .flags = .{
                        .no_collapse = true,

                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();

                    const i = blk: {
                        for (0..gst.str_buf.len) |idx| {
                            if (gst.str_buf[idx] == 0) break :blk idx;
                        }
                        break :blk 0;
                    };

                    zgui.text("log: {s}", .{gst.str_buf[0..i]});

                    if (zgui.button("exit", .{})) {
                        return .Exit;
                    }

                    if (zgui.button("main", .{})) {
                        return .GotoMain;
                    }
                }
            }
        }
    };

    pub const mainST = union(enum) {
        Print: Wit(Editor.main),
        Exit: Wit(Editor.exit),
        Modify: Wit(.{ Editor.action, Editor.main, Editor.main }),

        pub fn handler(gst: *GST) void {
            switch (genMsg(gst)) {
                .Print => |wit| {
                    wit.handler(gst);
                },
                .Exit => |wit| wit.handler(gst),
                .Modify => |wit| wit.handler(gst),
            }
        }

        fn genMsg(gst: *GST) @This() {
            const window = gst.window;
            while (true) {
                generic.clear_and_init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                if (window.shouldClose() or
                    window.getKey(.q) == .press or
                    window.getKey(.escape) == .press)
                    return .Exit;

                {
                    _ = zgui.begin("main", .{ .flags = .{
                        .no_collapse = true,

                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();

                    zgui.setCursorPos(gst.main.print);
                    if (zgui.button("print", .{})) {
                        return .Print;
                    }

                    zgui.setCursorPos(gst.main.exit);
                    if (zgui.button("exit", .{})) {
                        return .Exit;
                    }

                    zgui.setCursorPos(gst.main.modify);
                    if (zgui.button("modify", .{})) {
                        return .Modify;
                    }
                }
            }
        }
    };
};
