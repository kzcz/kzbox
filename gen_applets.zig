const std = @import("std");
pub fn main() !u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();
    defer arena.deinit();
    const args = try std.process.argsAlloc(alloc);
    if (args.len != 2) {
        std.debug.print("Usage: {s} ROOT\n", .{args[0]});
        return 1;
    }
    const cwd = std.fs.cwd();
    var file = try cwd.createFileZ(try std.fmt.allocPrintSentinel(alloc, "{s}/applets.zig", .{args[1]}, 0), .{});
    var writer = file.writer(&.{});
    var intr = &writer.interface;
    try intr.writeAll("pub const Applet = struct { name: []const u8, usage: []const u8, desc: []const u8, main: *const fn (args: [][:0]u8) anyerror!u8 };\npub inline fn load_applet(comptime name: []const u8, root: type) Applet {\n    return .{ .name = name, .usage = root.usage, .desc = root.desc, .main = root.main };\n}\npub const _ap = [_]Applet{\n");
    var dir = (try std.fs.cwd().openDir("applets", .{ .iterate = true })).iterate();
    while (try dir.next()) |entry| {
        if (entry.name.len < 4 or !std.mem.eql(u8, entry.name[entry.name.len - 4 ..], ".zig")) continue;
        try intr.print("    load_applet(\"{s}\", @import(\"applets/{s}\")),\n", .{ entry.name[0 .. entry.name.len - 4], entry.name });
    }
    try intr.writeAll("};\n");
    return 0;
}
