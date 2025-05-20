const std = @import("std");
const typedFsm = @import("typed_fsm");
const Witness = typedFsm.Witness;
const zgui = @import("zgui");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");

const content_dir = @import("build_options").content_dir;
const window_titlw = "TodoList";
const gl = zopengl.bindings;
const Window = glfw.Window;

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    try glfw.init();
    defer glfw.terminate();

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

    const window = try glfw.Window.create(1000, 800, window_titlw, null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    zgui.init(gpa);
    defer zgui.deinit();

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
    defer zgui.backend.deinit();
    // -------------------------------------
    var graph = typedFsm.Graph.init;
    try typedFsm.generate_graph(gpa, Todo, &graph);
    std.debug.print("{}\n", .{graph});
    // -------------------------------------
    var gst = GST.init(gpa, "TodoList", window);
    gst.action.ok[0] = 'O';
    gst.action.ok[1] = 'K';
    const wit = Todo.Wit(Todo.main){};
    wit.handler_normal(&gst);
}

const Entry = struct {
    id: i32,
    title: []const u8,
    completed: bool,
};

const Action = struct {
    ok: [20:0]u8 = @splat(0),
    color: [3]f32 = .{ 0, 0, 1 },

    pub fn render(self: *@This()) void {
        _ = zgui.inputText("title", .{
            .buf = &self.ok,
        });
        _ = zgui.colorPicker3("color", .{ .col = &self.color });
    }
};

const TmpEntry = struct {
    id: i32 = 0,
    title: [40:0]u8 = @splat(0),
    completed: bool = false,

    pub fn render(self: *@This()) void {
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
    action: Action = .{},

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
    action, //action add

    fn enter_fn(cst: typedFsm.sdzx(@This()), gst: *const GST) void {
        std.debug.print("cst: {}, gst: {any}\n", .{ cst, gst });
    }

    pub fn Wit(val: anytype) type {
        return typedFsm.Witness(@This(), typedFsm.val_to_sdzx(Todo, val), GST, enter_fn);
    }

    pub const exitST = union(enum) {
        pub fn handler(gst: *GST) void {
            std.debug.print("exit\n", .{});
            std.debug.print("gst: {any}\n", .{gst});
        }
    };

    pub fn actionST(st: typedFsm.sdzx(Todo)) type {
        return union(enum) {
            OK: typedFsm.Witness(Todo, st, GST, enter_fn),

            pub fn handler(gst: *GST) void {
                switch (genMsg(gst)) {
                    .OK => |wit| wit.handler(gst),
                }
            }

            fn genMsg(gst: *GST) @This() {
                const window = gst.window;
                var buf: [30]u8 = @splat(0);
                while (true) {
                    init(window);
                    defer {
                        zgui.backend.draw();
                        window.swapBuffers();
                    }

                    const nst = switch (st) {
                        .Term => |v| @tagName(v),
                        .Fun => |val| @tagName(val.fun),
                    };
                    const str = std.fmt.bufPrintZ(&buf, "{s}", .{nst}) catch unreachable;
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
        Exit: Wit(Todo.exit),
        Add: Wit(.{ Todo.action, Todo.add }),
        Delete: struct { wit: Wit(Todo.main) = .{}, id: i32 },
        Modify: struct { wit: Wit(.{ Todo.action, Todo.modify }) = .{}, id: i32 },
        Add_M: Wit(.{ Todo.action, .{ Todo.action, Todo.add } }),

        pub fn handler(gst: *GST) void {
            switch (genMsg(gst)) {
                .Exit => |wit| wit.handler(gst),
                .Add => |wit| wit.handler(gst),
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
                .Add_M => |wit| wit.handler(gst),
            }
        }

        fn genMsg(gst: *const GST) @This() {
            const window = gst.window;
            var buf: [30:0]u8 = @splat(0);
            while (true) {
                init(window);
                defer {
                    zgui.backend.draw();
                    window.swapBuffers();
                }

                if (window.shouldClose() or
                    window.getKey(.q) == .press or
                    window.getKey(.escape) == .press)
                    return .Exit;

                {
                    _ = zgui.begin("TodoList", .{ .flags = .{
                        .no_collapse = true,

                        .no_move = true,
                        .no_resize = true,
                    } });
                    defer zgui.end();

                    if (zgui.button("Add", .{})) {
                        return .Add;
                    }

                    if (zgui.button("Add_M", .{})) {
                        return .Add_M;
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

fn init(window: *Window) void {
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
