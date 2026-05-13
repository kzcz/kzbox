const std = @import("std");
pub fn main(init: std.process.Init) !u8 {
    const io = init.io;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const cwd = std.Io.Dir.cwd();
    var file = try cwd.createFile(io, "./applets.zig", .{});
    var writer = file.writer(io, &.{});
    var intr = &writer.interface;
    try intr.writeAll("pub const Applet = struct { name: []const u8, usage: []const u8, desc: []const u8, main: *const fn (args: [][:0]u8) anyerror!u8 };\npub inline fn load_applet(comptime name: []const u8, root: type) Applet {\n    return .{ .name = name, .usage = root.usage, .desc = root.desc, .main = root.main };\n}\npub const _ap = [_]Applet{\n");
    var dir = (try cwd.openDir(io, "applets", .{ .iterate = true })).iterate();
    while (try dir.next(io)) |entry| {
        if (entry.name.len < 4 or !std.mem.eql(u8, entry.name[entry.name.len - 4 ..], ".zig")) continue;
        try intr.print("    load_applet(\"{s}\", @import(\"applets/{s}\")),\n", .{ entry.name[0 .. entry.name.len - 4], entry.name });
    }
    try intr.writeAll("};\n");
    return 0;
}
