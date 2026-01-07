const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
const die = root.die;
pub const help: []const u8 = "Get the last element of a path, and optionally remove a suffix.";
const Parser = argp.Gen(.{ val("suffix", true, "Removes the suffix from each of following paths."), val("version", false, "Print the version string."), val("help", false, "Print this help message.") }, .{ .allow_intermix = false });
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
                    .version => {
                        try out.print("Version: {s}\n", .{root.detailed_version});
                        return 0;
                    },
                    .help => {
                        try Parser.help_printer(help, out);
                        return 0;
                    },
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
            else => {},
        }
    } else |_| {
        try parser.printLastError(eout, self_name);
        return 1;
    }
    var iargs = args[1..args.len];
    if (iargs.len > 0 and std.mem.eql(u8, iargs[0], "--")) iargs = iargs[1..iargs.len];
    if (iargs.len == 0) return die(1, self_name, "Missing arguments", .{});
    if (suffix) |suff| {
        if (iargs.len < 3) die(1, self_name, "Missing arguments", .{});
        for (iargs[2..iargs.len]) |arg| {
            try out.print("{s}\n", .{basename(arg, suff)});
            try out.flush();
        }
        return 0;
    }
    if (iargs.len < 3) {
        if (iargs.len == 2) suffix = iargs[1];
        try out.print("{s}\n", .{basename(iargs[0], suffix)});
        return 0;
    }
    die(1, self_name, "Extra arguments '{s}' and beyond.", .{iargs[3]});

    return 0;
}
fn basename(str: []const u8, suffix: ?[]const u8) []const u8 {
    const bname = lib.properPosixBasename(str);
    if (suffix) |suff| {
        if (std.mem.eql(u8, bname, suff)) return bname;
        return lib.removeSuffix(bname, suff);
    } else return bname;
}
