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

    const StartState = Todo(Main);
    // -------------------------------------
    var graph = polystate.Graph.init;
    try graph.generate(gpa, StartState);
    std.debug.print("{}\n", .{graph});
    // -------------------------------------

    var ctx = Context.init(gpa, "TodoList", window);

    var next = &StartState.conthandler;
    var exit: bool = false;

    while (!exit) {
        generic.clear_and_init(window);
        defer {
            zgui.backend.draw();
            window.swapBuffers();
        }

        sw: switch (next(&ctx)) {
            .exit => exit = true,
            .no_trasition => {},
            .next => |fun| next = fun,
            .current => |fun| {
                next = fun;
                continue :sw fun(&ctx);
            },
        }
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

pub fn Todo(state: type) type {
    return polystate.FSM(1, Context, null, state);
}

pub const Modify = union(enum) {
    modify_entry: Todo(Main),

    pub fn zgui_render(ctx: *Context) void {
        ctx.modify.zgui_render();
    }

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
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
        return .{ .current = .modify_entry };
    }
};

pub const Add = union(enum) {
    add_entry: Todo(Main),

    pub fn zgui_render(ctx: *Context) void {
        ctx.add.zgui_render();
    }

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
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
        return .{ .current = .add_entry };
    }
};

pub fn AreYouSure(yes: type, no: type) type {
    return generic.AreYouSure(Todo, Context, generic.zgui_are_you_sure_genMsg, yes, no);
}

pub fn Action(mst: type, jst: type) type {
    return generic.Action(Todo, Context, generic.zgui_action_genMsg, mst, jst);
}
pub const Exit = polystate.Exit;

pub const Main = union(enum) {
    // zig fmt: off
    exit             : Todo(AreYouSure(Exit, Main)),
    add              : Todo(Action(Add, Add)),
    modify           : Todo(Action(Modify, Modify)), // = .{}, id: i32 },
    modify_action    : Todo(Action(Action(Exit, Exit), Main)),
    modify_areYouSure: Todo(Action(AreYouSure(Exit, Exit), Main)),
    // zig fmt: on

    pub fn conthandler(ctx: *Context) polystate.NextState(@This()) {
        const window = ctx.window;
        var buf: [30:0]u8 = @splat(0);

        if (window.shouldClose() or
            window.getKey(.q) == .press or
            window.getKey(.escape) == .press)
            return .{ .next = .exit };

        _ = zgui.begin("main", .{ .flags = .{
            .no_collapse = true,

            .no_move = true,
            .no_resize = true,
        } });
        defer zgui.end();

        if (zgui.button("Exit", .{})) {
            return .{ .next = .exit };
        }

        if (zgui.button("Add", .{})) {
            return .{ .next = .add };
        }

        if (zgui.button("Modify Action", .{})) {
            return .{ .next = .modify_action };
        }

        if (zgui.button("Modify Are You Sure", .{})) {
            return .{ .next = .modify_areYouSure };
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
            if (zgui.button(d_name, .{})) ctx.delete(entry.key_ptr.*) catch unreachable;
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

                return .{ .next = .modify };
            }
        }
        return .no_trasition;
    }
};
