const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const strip = b.option(bool, "strip", "Whether to strip the binary") orelse false;
    var as_buf = try std.array_list.Aligned(u8, null).initCapacity(b.allocator, 16 * 1024);
    try as_buf.print(b.allocator, "{s}", .{"pub const Applet = struct { name: []const u8, help: []const u8, main: *const fn (args: [][:0]u8) anyerror!u8 };\npub fn load_applet(comptime name: []const u8, root: type) Applet {\n    return .{ .name = name, .help = root.help, .main = root.main };\n}\npub var _ap = [_]Applet{\n"});
    var dir = (try b.path("").getPath3(b, null).openDir("applets", .{ .iterate = true })).iterate();

    while (try dir.next()) |entry| {
        if (entry.name.len < 4 or !std.mem.eql(u8, entry.name[entry.name.len - 4 ..], ".zig")) continue;
        try as_buf.print(b.allocator, "\tload_applet(\"{s}\", @import(\"applets/{s}\")),\n", .{ entry.name[0 .. entry.name.len - 4], entry.name });
    }
    try as_buf.print(b.allocator, "\n}};\n", .{});
    const write_applets = b.addWriteFile(b.pathFromRoot("applets.zig"), try as_buf.toOwnedSlice(b.allocator));
    const root = b.createModule(.{ .root_source_file = b.path("kzbox.zig"), .target = target, .optimize = optimize, .strip = strip });
    root.addImport("kzlib", b.createModule(.{ .root_source_file = b.path("lib.zig"), .target = target, .optimize = optimize, .strip = strip }));
    const exe = b.addExecutable(.{ .name = "kzbox", .root_module = root, .version = std.SemanticVersion.parse(@import("build.zig.zon").version) catch unreachable });
    b.install_tls.step.dependOn(&write_applets.step);
    b.installArtifact(exe);
}
