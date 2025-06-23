const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const polystate = b.dependency("polystate", .{ .target = target, .optimize = optimize });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path(b.fmt("src/counter.zig", .{})),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "polystate", .module = polystate.module("root") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "counter",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("counter", b.fmt("Run the counter", .{}));
    run_step.dependOn(&run_cmd.step);
}
