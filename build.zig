const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zig fmt: off
    const polystate  = b.dependency("polystate",  .{.target = target, .optimize = optimize});
    const zopengl    = b.dependency("zopengl",    .{.target = target});
    const zglfw      = b.dependency("zglfw",      .{.target = target, .optimize = optimize});
    const zgui       = b.dependency("zgui",       .{.target = target, .optimize = optimize, .backend = .glfw_opengl3,});
    const raylib_dep = b.dependency("raylib_zig", .{.target = target, .optimize = optimize});
    // zig fmt: on

    const install_content_step = b.addInstallFile(
        b.path("data/FiraMono.ttf"),
        b.pathJoin(&.{ "bin", "data/FiraMono.ttf" }),
    );
    b.default_step.dependOn(&install_content_step.step);

    const dir = std.fs.cwd();
    const src_dir = dir.openDir("src", .{ .iterate = true }) catch unreachable;
    var iter = src_dir.iterate();

    while (iter.next() catch unreachable) |entry| {
        const ext = std.fs.path.extension(entry.name);
        if (entry.kind == .file and
            std.mem.eql(u8, ext, ".zig") and
            std.mem.startsWith(u8, entry.name, "exe-"))
        {
            const exe_name = entry.name[4 .. entry.name.len - 4];

            const exe_mod = b.createModule(.{
                .root_source_file = b.path(b.fmt("src/{s}", .{entry.name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "polystate", .module = polystate.module("root") },
                    .{ .name = "zglfw", .module = zglfw.module("root") },
                    .{ .name = "zopengl", .module = zopengl.module("root") },
                    .{ .name = "zgui", .module = zgui.module("root") },
                    .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                    .{ .name = "raygui", .module = raylib_dep.module("raygui") },
                },
            });

            const exe = b.addExecutable(.{
                .name = exe_name,
                .root_module = exe_mod,
            });
            exe.linkLibrary(zglfw.artifact("glfw"));
            exe.linkLibrary(zgui.artifact("imgui"));
            exe.linkLibrary(raylib_dep.artifact("raylib"));

            b.installArtifact(exe);

            { //add options
                const exe_options = b.addOptions();
                exe.root_module.addOptions("build_options", exe_options);
                exe_options.addOption([]const u8, "content_dir", "data/");
            }

            const run_cmd = b.addRunArtifact(exe);

            run_cmd.step.dependOn(b.getInstallStep());

            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step(exe_name, b.fmt("Run the {s}", .{exe_name}));
            run_step.dependOn(&run_cmd.step);
        }
    }
}
