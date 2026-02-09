const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "logname" ++ lib.orCommon("logname");
pub const desc: []const u8 = "Print the login name of the current user.";
const Parser = argp.Gen(argp.std_vh, .{}, .{ .usage = usage, .desc = desc });
const die = root.die;
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    var parser = Parser.init(args);
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
            .positional => |f| die(1, "extra operand '{s}'", .{f}),
            else => unreachable,
        }
    } else |_| {
        try parser.printLastError(eout);
        return 1;
    }
    lib.dieIfNotLibC();
    if (lib.getlogin() catch null) |logname| {
        try out.print("{s}\n", .{logname});
        try out.flush();
        return 0;
    }
    return die(1, "unable to get the log name.", .{});
}
