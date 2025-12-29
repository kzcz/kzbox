const std = @import("std");
const blt = @import("builtin");
const lib = @import("kzlib");
const _apts = @import("applets.zig");
pub var alloc = std.heap.smp_allocator;
var wo_buf: [512]u8 = undefined;
var we_buf: [512]u8 = undefined;
var wo = std.fs.File.stdout().writer(&wo_buf);
var we = std.fs.File.stderr().writer(&we_buf);
pub var out: *std.io.Writer = &wo.interface;
pub var eout: *std.io.Writer = &we.interface;
pub const version = @import("build.zig.zon").version;
pub const detailed_version = version ++ " zig " ++ blt.zig_version_string ++ " os " ++ @tagName(blt.os.tag) ++ " cpu " ++ @tagName(blt.cpu.arch) ++ " " ++ blt.cpu.model.name;
pub inline fn die(code: u8, util_name: []const u8, comptime fmt: []const u8, args: anytype) noreturn {
    eout.writeAll(util_name) catch unreachable;
    eout.print(": " ++ fmt ++ "\n", args) catch unreachable;
    eout.flush() catch unreachable;
    std.process.exit(code);
}
const Applet = _apts.Applet;
pub const applets: []Applet = _apts._ap[0.._apts._ap.len];
pub fn main() !u8 {
    defer out.flush() catch unreachable;
    defer eout.flush() catch unreachable;
    const args = try std.process.argsAlloc(alloc);
    var fed_args = args;
    var bname: []u8 = undefined;
    for (0..args.len) |_| {
        bname = @constCast(std.fs.path.basename(fed_args[0]));
        for (0..bname.len) |i| bname[i] |= 0x20;
        if (!std.mem.eql(u8, bname, "kzbox")) break;
        fed_args = fed_args[1..];
    }
    for (applets) |applet| {
        if (std.mem.eql(u8, bname, applet.name)) return applet.main(fed_args) catch |err| die(1, bname, "{s}", .{@errorName(err)});
    }
    if (std.mem.eql(u8, bname, "kzbox")) {
        var mock_args = try alloc.alloc([:0]u8, 1);
        mock_args[0] = try alloc.dupeZ(u8, "help");
        return applets[0].main(mock_args) catch |err| die(1, "help", "{s}", .{@errorName(err)});
    }
    die(1, bname, "Applet not found", .{});
}
