const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const die = root.die;
const val = argp.val;
pub const usage: []const u8 = "tty";
pub const desc: []const u8 = "Print the tty name.";
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const self_name = args[0];
    var pbuf: [64]u8 = undefined;
    const str = lib.ttyname(&pbuf) catch |err| die(2, self_name, "readlink: {s}", .{@errorName(err)});
    out.print("{s}\n", .{str}) catch |err| die(2, self_name, "print: {s}", .{@errorName(err)});
    return @intFromBool(std.mem.eql(u8, "not a tty", str));
}
