const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const help: []const u8 = "Get the final pathname component of a set of paths.";
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
            .positional => |f| {
                try out.print("[EDIT ME] input: \"{s}\" output: \"{s}\"\n", .{ f, dirname(f) });
            },
            else => unreachable,
        }
    } else |_| {
        try parser.printLastError(eout, self_name);
        return 1;
    }
    return 0;
}
fn dirname(path: []const u8) []const u8 {
    if (path.len == 0) return ".";
    const p = lib.scalarTrimEnd(path, '/');
    if (p.len == 0) return "/";
    const p2 = if (std.mem.lastIndexOfScalar(u8, p, '/')) |idx| p[0..idx] else return if (path[0] == '/') "/" else ".";
    const p3 = lib.scalarTrimEnd(p2, '/');
    if (p3.len == 0) return "/";
    return p3;
}
