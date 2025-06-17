const std = @import("std");
const polystate = @import("polystate");
const Witness = polystate.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const generic = @import("generic.zig");
const Window = glfw.Window;

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const window = try generic.init_zgui(gpa, "TodoList");
    defer generic.deinit_zgui(window);

    // -------------------------------------
    var graph = polystate.Graph.init;
    try graph.generate(gpa, Todo);
    std.debug.print("{}\n", .{graph});
    // -------------------------------------
    var gst = GST.init(gpa, "TodoList", window);
    const wit = Todo.Wit(Todo.main){};
    wit.handler_normal(&gst);
}

const Entry = struct {
    id: i32,
    title: []const u8,
    completed: bool,
};

const TmpEntry = struct {
    id: i32 = 0,
    title: [40:0]u8 = @splat(0),
    completed: bool = false,

    pub fn zgui_render(self: *@This()) void {
        _ = zgui.inputText("title", .{
            .buf = &self.title,
        });
        _ = zgui.checkbox("completed", .{ .v = &self.completed });
    }
};

const GST = struct {
    gpa: std.mem.Allocator,
    todos: std.AutoArrayHashMapUnmanaged(i32, Entry),
    global_id: i32,
    title: []const u8,
    window: *Window,
    //
    modify: TmpEntry = .{},
    add: TmpEntry = .{},
    action: generic.Action = .{},
    are_you_sure: generic.AreYouSure = .{},

    pub fn init(gpa: std.mem.Allocator, title: []const u8, window: *Window) GST {
        return .{
            .gpa = gpa,
            .todos = .empty,
            .global_id = 0,
            .title = title,
            .window = window,
        };
    }

    pub fn update(self: *@This(), todo: Entry) !void {
        if (self.todos.get(todo.id)) |old_todo| {
            //modify
            self.gpa.free(old_todo.title);
            try self.todos.put(self.gpa, todo.id, todo);
        } else {
            //add
            try self.todos.put(self.gpa, todo.id, todo);
        }
    }

    pub fn delete(self: *@This(), id: i32) !void {
        _ = self.todos.orderedRemove(id);
    }

    pub fn fresh_id(self: *@This()) i32 {
        const i = self.global_id;
        self.global_id += 1;
        return i;
    }
};

const Todo = enum {
    exit,
    main,
    add,
    modify,
    action, //action add add
    are_you_sure,

    fn enter_fn(cst: polystate.sdzx(@This()), gst: *const GST) void {
        std.debug.print("cst: {}, gst: {any}\n", .{ cst, gst });
    }

    pub fn Wit(val: anytype) type {
        return polystate.Witness(@This(), GST, enter_fn, polystate.val_to_sdzx(Todo, val));
    }

    pub const exitST = union(enum) {
        pub fn handler(gst: *GST) void {
            std.debug.print("exit\n", .{});
            std.debug.print("gst: {any}\n", .{gst});
        }
    };

    pub fn are_you_sureST(yes: polystate.sdzx(Todo), no: polystate.sdzx(Todo)) type {
        return generic.are_you_sureST(
            Todo,
            GST,
            enter_fn,
            generic.zgui_are_you_sure_genMsg,
            yes,
            no,
        );
    }

    pub fn actionST(mst: polystate.sdzx(Todo), jst: polystate.sdzx(Todo)) type {
        return generic.actionST(Todo, GST, enter_fn, generic.zgui_action_genMsg, mst, jst);
    }

    pub const modifyST = union(enum) {
        ModifyEntry: Wit(Todo.main),

        pub fn handler(gst: *GST) void {
            switch (genMsg()) {
                .ModifyEntry => |wit| {
                    const tmp = gst.modify;

                    const idx = blk: {
                        for (0..tmp.title.len) |i| {
                            if (tmp.title[i] == 0) break :blk i;
                        }
                        break :blk 0;
                    };

                    const entry: Entry = .{
                        .completed = tmp.completed,
                        .title = gst.gpa.dupe(u8, tmp.title[0..idx]) catch unreachable,
                        .id = tmp.id,
                    };
                    gst.update(entry) catch unreachable;
                    wit.handler(gst);
                },
            }
        }

        fn genMsg() @This() {
            return .ModifyEntry;
        }
    };

    pub const addST = union(enum) {
        AddEntry: Wit(Todo.main),

        pub fn handler(gst: *GST) void {
            switch (genMsg()) {
                .AddEntry => |wit| {
                    const tmp = gst.add;

                    const idx = blk: {
                        for (0..tmp.title.len) |i| {
                            if (tmp.title[i] == 0) break :blk i;
                        }
                        break :blk 0;
                    };

                    const entry: Entry = .{
                        .completed = tmp.completed,
                        .title = gst.gpa.dupe(u8, tmp.title[0..idx]) catch unreachable,
                        .id = gst.fresh_id(),
                    };
                    gst.update(entry) catch unreachable;
                    wit.handler(gst);
                },
            }
        }

        fn genMsg() @This() {
            return .AddEntry;
        }
    };

    pub const mainST = union(enum) {
        // zig fmt: off
        Exit            : Wit(.{ Todo.are_you_sure, Todo.exit, Todo.main }),
        Add             : Wit(.{ Todo.action, Todo.add, Todo.add }),
        Delete          : struct { wit: Wit(Todo.main) = .{}, id: i32 },
        Modify          : struct { wit: Wit(.{ Todo.action, Todo.modify, Todo.modify }) = .{}, id: i32 },
        ModifyAction    : Wit(.{ Todo.action, Todo.action, Todo.main }),
        ModifyAreYouSure: Wit(.{ Todo.action, Todo.are_you_sure, Todo.main }),
        // zig fmt: on

        pub fn handler(gst: *GST) void {
            switch (genMsg(gst)) {
                .Exit => |wit| wit.handler(gst),
                .Add => |wit| wit.handler(gst),
                .ModifyAction => |wit| wit.handler(gst),
                .ModifyAreYouSure => |wit| wit.handler(gst),
                .Delete => |val| {
                    gst.delete(val.id) catch unreachable;
                    val.wit.handler(gst);
                },
                .Modify => |val| {
                    const v = gst.todos.get(val.id).?;
                    gst.modify = .{
                        .id = v.id,
                        .completed = v.completed,
                    };
                    for (v.title, 0..) |vv, i| {
                        gst.modify.title[i] = vv;
                    }
                    val.wit.handler(gst);
                },
            }
        }

        fn genMsg(gst: *const GST) @This() {
            const window = gst.window;
            var buf: [30:0]u8 = @splat(0);
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

                    if (zgui.button("Exit", .{})) {
                        return .Exit;
                    }

                    if (zgui.button("Add", .{})) {
                        return .Add;
                    }

                    if (zgui.button("Modify Action", .{})) {
                        return .ModifyAction;
                    }

                    if (zgui.button("Modify Are You Sure", .{})) {
                        return .ModifyAreYouSure;
                    }

                    _ = zgui.beginTable("TodoList", .{
                        .column = 4,
                        .flags = .{ .scroll_y = true },
                    });
                    defer zgui.endTable();
                    zgui.tableNextRow(.{ .row_flags = .{ .headers = true } });
                    _ = zgui.tableNextColumn();
                    zgui.text("Title", .{});
                    _ = zgui.tableNextColumn();
                    zgui.text("Completed", .{});

                    var iter = gst.todos.iterator();
                    while (iter.next()) |entry| {
                        zgui.tableNextRow(.{});
                        _ = zgui.tableNextColumn();
                        zgui.text("{s}", .{entry.value_ptr.title});
                        _ = zgui.tableNextColumn();
                        zgui.text("{}", .{entry.value_ptr.completed});
                        _ = zgui.tableNextColumn();
                        const d_name = std.fmt.bufPrintZ(
                            &buf,
                            "Delete ##{d}",
                            .{entry.key_ptr.*},
                        ) catch unreachable;
                        if (zgui.button(d_name, .{})) {
                            return .{ .Delete = .{ .id = entry.key_ptr.* } };
                        }
                        _ = zgui.tableNextColumn();
                        const m_name = std.fmt.bufPrintZ(
                            &buf,
                            "Modify ##{d}",
                            .{entry.key_ptr.*},
                        ) catch unreachable;
                        if (zgui.button(m_name, .{})) {
                            return .{ .Modify = .{ .id = entry.key_ptr.* } };
                        }
                    }
                }
            }
        }
    };
};
