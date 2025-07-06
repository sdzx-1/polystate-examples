const std = @import("std");
const ps = @import("polystate");
const zgui = @import("zgui");
const glfw = @import("zglfw");
const generic = @import("generic.zig");
const Window = glfw.Window;

pub fn main() !void {
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    const window = try generic.init_zgui(gpa, "TodoList");
    defer generic.deinit_zgui(window);

    const StartState = Todo(.next, Main);
    // -------------------------------------
    const graph = try ps.Graph.initWithFsm(gpa, StartState, 20);

    const dot_file = try std.fs.cwd().createFile("t.dot", .{});
    try graph.generateDot(dot_file.writer());

    const mermaid_file = try std.fs.cwd().createFile("t.mmd", .{});
    try graph.generateMermaid(mermaid_file.writer());
    // -------------------------------------

    var ctx = Context.init(gpa, "TodoList", window);

    const Runner = ps.Runner(20, false, StartState);
    var curr_id: ?Runner.StateId = Runner.idFromState(Main);
    while (curr_id) |id| {
        generic.clear_and_init(window);
        defer {
            zgui.backend.draw();
            window.swapBuffers();
        }
        curr_id = Runner.runHandler(id, &ctx);
    }
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

const Context = struct {
    gpa: std.mem.Allocator,
    todos: std.AutoArrayHashMapUnmanaged(i32, Entry),
    global_id: i32,
    title: []const u8,
    window: *Window,
    //
    modify: TmpEntry = .{},
    add: TmpEntry = .{},
    action: generic.ActionData = .{},
    are_you_sure: generic.AreYouSureData = .{},

    pub fn init(gpa: std.mem.Allocator, title: []const u8, window: *Window) Context {
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

fn enter_fn(ctx: *Context, state: type) void {
    _ = ctx;
    // std.debug.print("{s}\n", .{@typeName(state)});
    _ = state;
}

pub fn Todo(method: ps.Method, state: type) type {
    return ps.FSM("Todo", .suspendable, Context, enter_fn, method, state);
}

pub const Modify = union(enum) {
    modify_entry: Todo(.current, Main),

    pub fn zgui_render(ctx: *Context) void {
        ctx.modify.zgui_render();
    }

    pub fn handler(ctx: *Context) @This() {
        const tmp = ctx.modify;

        const idx = blk: {
            for (0..tmp.title.len) |i| {
                if (tmp.title[i] == 0) break :blk i;
            }
            break :blk 0;
        };

        const entry: Entry = .{
            .completed = tmp.completed,
            .title = ctx.gpa.dupe(u8, tmp.title[0..idx]) catch unreachable,
            .id = tmp.id,
        };
        ctx.update(entry) catch unreachable;
        return .modify_entry;
    }
};

pub const Add = union(enum) {
    add_entry: Todo(.current, Main),

    pub fn zgui_render(ctx: *Context) void {
        ctx.add.zgui_render();
    }

    pub fn handler(ctx: *Context) @This() {
        const tmp = ctx.add;

        const idx = blk: {
            for (0..tmp.title.len) |i| {
                if (tmp.title[i] == 0) break :blk i;
            }
            break :blk 0;
        };

        const entry: Entry = .{
            .completed = tmp.completed,
            .title = ctx.gpa.dupe(u8, tmp.title[0..idx]) catch unreachable,
            .id = ctx.fresh_id(),
        };
        ctx.update(entry) catch unreachable;
        return .add_entry;
    }
};

pub fn AreYouSure(yes: type, no: type) type {
    return generic.AreYouSure(Todo, yes, no);
}

pub fn Action(mst: type, jst: type) type {
    return generic.Action(Todo, mst, jst);
}
pub const Exit = ps.Exit;

pub const Main = union(enum) {
    // zig fmt: off
    exit             : Todo(.next, AreYouSure(AreYouSure(Exit, Main), Main)),
    add              : Todo(.next, Action(Add, Add)),
    modify           : Todo(.next, Action(Modify, Modify)),
    modify_action    : Todo(.next, Action(Action(Exit, Exit), Main)),
    modify_areYouSure: Todo(.next, Action(AreYouSure(Exit, Exit), Main)),
    no_trasition     : Todo(.next, @This()),
    // zig fmt: on

    pub fn handler(ctx: *Context) @This() {
        const window = ctx.window;
        var buf: [30:0]u8 = @splat(0);

        if (window.shouldClose() or
            window.getKey(.q) == .press or
            window.getKey(.escape) == .press)
            return .exit;

        _ = zgui.begin("main", .{ .flags = .{
            .no_collapse = true,

            .no_move = true,
            .no_resize = true,
        } });
        defer zgui.end();

        if (zgui.button("Exit", .{})) {
            return .exit;
        }

        if (zgui.button("Add", .{})) {
            return .add;
        }

        if (zgui.button("Modify Action", .{})) {
            return .modify_action;
        }

        if (zgui.button("Modify Are You Sure", .{})) {
            return .modify_areYouSure;
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

        var iter = ctx.todos.iterator();
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
                ctx.delete(entry.key_ptr.*) catch unreachable;
                return .no_trasition;
            }
            _ = zgui.tableNextColumn();
            const m_name = std.fmt.bufPrintZ(
                &buf,
                "Modify ##{d}",
                .{entry.key_ptr.*},
            ) catch unreachable;
            if (zgui.button(m_name, .{})) {
                const v = ctx.todos.get(entry.key_ptr.*).?;
                ctx.modify = .{
                    .id = v.id,
                    .completed = v.completed,
                };
                for (v.title, 0..) |vv, i| {
                    ctx.modify.title[i] = vv;
                }

                return .modify;
            }
        }
        return .no_trasition;
    }
};
