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

    var gst = GST{ .window = window };

    const mainWit = Editor.Wit(Editor.main){};
    mainWit.handler_normal(&gst);
}

const GST = struct {
    window: *Window,
};

const Editor = enum {
    exit,
    main,

    fn enter_fn(cst: typedFsm.sdzx(@This()), gst: *const GST) void {
        std.debug.print("cst: {}, gst: {any}\n", .{ cst, gst });
    }

    pub fn Wit(val: anytype) type {
        return typedFsm.Witness(@This(), typedFsm.val_to_sdzx(Editor, val), GST, enter_fn);
    }

    pub const exitST = union(enum) {
        pub fn handler(gst: *GST) void {
            std.debug.print("exit\n", .{});
            std.debug.print("gst: {any}\n", .{gst});
        }
    };

    pub const mainST = union(enum) {
        Print: Wit(Editor.main),
        Exit: Wit(Editor.exit),

        pub fn handler(gst: *GST) void {
            switch (genMsg(gst)) {
                .Print => |wit| {
                    std.debug.print("nice\n", .{});
                    wit.handler(gst);
                },
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
                    _ = zgui.begin("main", .{ .flags = .{
                        .no_collapse = true,

                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();

                    if (zgui.button("print", .{})) {
                        return .Print;
                    }

                    if (zgui.button("exit", .{})) {
                        return .Exit;
                    }
                }
            }
        }
    };
};
