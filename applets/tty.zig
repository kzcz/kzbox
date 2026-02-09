const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const dieErr = root.dieErr;
pub const usage: []const u8 = "tty";
pub const desc: []const u8 = "Print the tty name.";
pub fn main(_: [][:0]u8) !u8 {
    const out = root.out;
    var pbuf: [64]u8 = undefined;
    const str = lib.ttyname(&pbuf) catch |err| dieErr(2, "readlink", err);
    out.print("{s}\n", .{str}) catch |err| dieErr(2, "print", err);
    return @intFromBool(std.mem.eql(u8, "not a tty", str));
}
