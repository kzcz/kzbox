const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const help: []const u8 = "[[change this]] Template for building applets.";
const Parser = argp.Gen(.{ val("version", false, "Print the version string."), val("help", false, "Print this help message.") }, .{ .allow_intermix = false });
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
                    .version => {
                        try out.print("Version: {s}\n", .{root.detailed_version});
                        break;
                    },
                    .help => {
                        try Parser.help_printer(help, out);
                        break;
                    },
                    else => unreachable,
                }
            },
            else => {},
        }
        try out.print("{}\n", .{arg});
        try out.flush();
    } else |_| {
        try parser.printLastError(eout, self_name);
        return 1;
    }
    return 0;
}
