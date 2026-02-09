const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "kfmt" ++ lib.orCommon("kfmt");
pub const desc: []const u8 = "Killed Formatter";
const Parser = argp.Gen(argp.std_vh, .{}, .{ .usage = usage, .desc = desc });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
    _ = alloc;
    var parser = Parser.init(args);
    const self_name = parser.argv0;
    _ = self_name;
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
            .positional => {},
            else => unreachable,
        }
        try out.print("{}\n", .{arg});
        try out.flush();
    } else |_| {
        try parser.printLastError(eout);
        return 1;
    }
    return 0;
}
