const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Whether to strip the binary") orelse false;
    const tool = b.addExecutable(.{ .name = "gen_applets", .root_module = b.createModule(.{ .root_source_file = b.path("gen_applets.zig"), .target = b.graph.host, .strip = true, .optimize = .ReleaseSafe }) });
    const tstep = b.addRunArtifact(tool);
    tstep.addArg(b.build_root.path.?);
    const root = b.createModule(.{ .root_source_file = b.path("kzbox.zig"), .target = target, .optimize = optimize, .strip = strip });
    root.addAnonymousImport("kzlib", .{ .root_source_file = b.path("lib.zig"), .target = target, .optimize = optimize, .strip = strip });
    const exe = b.addExecutable(.{ .name = "kzbox", .root_module = root, .version = std.SemanticVersion.parse(@import("build.zig.zon").version) catch unreachable });
    exe.step.dependOn(tstep.step);
    b.installArtifact(exe);
}
