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
}

const GST = struct {};

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

        // pub fn handler(gst: *GST) void {}
    };
};
