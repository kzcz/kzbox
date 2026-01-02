const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const die = root.die;
const val = argp.val;
pub const help: []const u8 = "Print the tty name.";
const nat = "not a tty";
const Parser = argp.Gen(.{ val("version", false, "Print the version string."), val("help", false, "Print this help message.") }, .{ .allow_intermix = false });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const self_name = args[0];
    var pbuf: [64]u8 = undefined;
    const str = @as([]const u8, if (std.posix.isatty(0)) std.posix.readlinkZ("/proc/self/fd/0", &pbuf) catch |err| die(2, self_name, "readlink: {s}", .{@errorName(err)}) else nat);
    out.print("{s}\n", .{str}) catch |err| die(2, self_name, "print: {s}", .{@errorName(err)});
    return @intFromBool(@intFromPtr(str.ptr) == @intFromPtr(nat));
}
