const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "logname" ++ lib.orCommon("logname");
pub const desc: []const u8 = "Print the login name of the current user.";
const Parser = argp.Gen(.{ val("version", false, "Print the version string."), val("help", false, "Print this help message.") }, .{}, .{ .usage = usage, .desc = desc });
const die = root.die;
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
    const self_name = args[0];
    _ = alloc;
    var parser = Parser.init(args[1..]);
    while (parser.nextArg()) |arg| {
        switch (arg) {
            .eof => break,
            .flag => |f| {
                switch (f) {
                    .version => return lib.putVer(out),
                    .help => return Parser.help_printer(out),
                    else => unreachable,
                }
            },
            .positional => |f| die(1, self_name, "extra operand '{s}'", .{f}),
            else => unreachable,
        }
    } else |_| {
        try parser.printLastError(eout, self_name);
        return 1;
    }
    lib.dieIfNotLibC(self_name);
    if (lib.getlogin() catch null) |logname| {
        try out.print("{s}\n", .{logname});
        try out.flush();
        return 0;
    }
    return die(1, self_name, "unable to get the log name.", .{});
}
