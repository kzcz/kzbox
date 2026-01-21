const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
const die = root.die;
pub const usage: []const u8 = "basename <path> [suffix]\n\tor basename --suffix <suffix> <path1> [path2 [...]]" ++ lib.orCommon("basename");
pub const desc: []const u8 = "Get the last element of a path (or list of), and optionally, remove a suffix.";
const Parser = argp.Gen(.{ val("suffix", true, "Removes the suffix from each of following paths."), val("version", false, "Print the version string."), val("help", false, "Print this help message.") }, .{}, .{ .usage = usage, .desc = desc });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
    const self_name = args[0];
    _ = alloc;
    var parser = Parser.init(args[1..]);
    var idx: usize = 0;
    var suffix: ?[]const u8 = null;
    while (parser.nextArg()) |arg| {
        idx += 1;
        switch (arg) {
            .eof => break,
            .flag => |f| {
                switch (f) {
                    .version => return lib.putVer(out),
                    .help => return Parser.help_printer(out),
                    else => unreachable,
                }
            },
            .flag_args => |f| {
                const source, const value = f;
                if (source != .suffix) unreachable;
                if (idx != 1) die(1, self_name, "Suffix flag may only be provided as the first argument.", .{});
                if (value.len == 0) die(1, self_name, "Specified an empty suffix.", .{});
                suffix = value;
            },
            .positional => break,
        }
    } else |_| {
        try parser.printLastError(eout, self_name);
        return 1;
    }
    const iargs = args[parser.idx..args.len];
    if (iargs.len == 0) Parser.dieMissingArguments(eout, self_name);
    if (suffix) |suff| {
        for (iargs) |arg| {
            try out.print("{s}\n", .{basename(arg, suff)});
            try out.flush();
        }
        return 0;
    }
    if (iargs.len >= 3) die(1, self_name, "Extra arguments '{s}' and beyond.", .{iargs[2]});
    if (iargs.len == 2) suffix = iargs[1];
    try out.print("{s}\n", .{basename(iargs[0], suffix)});
    return 0;
}
fn basename(str: []const u8, suffix: ?[]const u8) []const u8 {
    const bname = lib.properPosixBasename(str);
    if (suffix) |suff| {
        if (std.mem.eql(u8, bname, suff)) return bname;
        return lib.removeSuffix(bname, suff);
    } else return bname;
}
