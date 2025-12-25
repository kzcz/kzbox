const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const help: []const u8 = "[[change this]] Template for building applets.";
const Parser = argp.Gen(.{ val("version", false), val("help", false) }, .{ .allow_intermix = false });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
    const self_name = args[0];
    _ = alloc;
    var parser = Parser.init(args[1..]);
    while (parser.nextArg()) |arg| {
        if (arg.source == null and arg.value == null) break;
        if (arg.source) |s| {
            switch (s) {
                .version => {
                    try out.print("Version: {s}\n", .{root.detailed_version});
                    break;
                },
                .help => {
                    try lib.help_printer(Parser, .{ .version = "Print the version string.", .help = "Print this help message." }, help, out);
                    break;
                },
                else => unreachable,
            }
        }
        try out.print(".{{ .source = {?}, .value = {?s} }}\n", .{ arg.source, arg.value });
    } else |_| {
        try parser.printLastError(eout, self_name);
        return 1;
    }
    return 0;
}
