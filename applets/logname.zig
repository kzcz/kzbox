const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "logname" ++ lib.orCommon("logname");
pub const desc: []const u8 = "Print the login name of the current user.";
const Parser = argp.Gen(.{ val("version", false, "Print the version string."), val("help", false, "Print this help message.") }, .{}, .{ .usage = usage, .desc = desc });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const die = root.die;
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
    if (loginuid()) |v| {
        if (std.c.getpwuid(@intCast(v))) |pw| {
            try out.print("{s}\n", .{pw.name orelse die(1, self_name, "unable to get the log name.", .{})});
            try out.flush();
            return 0;
        }
        die(1, self_name, "getpwuid: {s}", .{lib.strerror(std.c._errno().*)});
    }
    var name_buf: [64]u8 = undefined;
    const name = try lib.ttyname(&name_buf);
    if (std.mem.eql(u8, name, "not a tty")) die(1, self_name, "not a tty", .{});
    var utmp_iter = lib.UTmpIterator().init() catch unreachable;
    const name_wo_dev = name[5..name.len];
    while (utmp_iter.next()) |oent| {
        if (oent) |ent| {
            if (ent.ut_type != 7) continue;
            if (std.mem.eql(u8, ent.ut_line[0 .. std.mem.indexOfScalar(u8, &ent.ut_line, 0) orelse ent.ut_line.len], name_wo_dev)) {
                try out.print("{s}\n", .{ent.ut_user});
                try out.flush();
                return 0;
            }
        } else break;
    } else |err| die(1, self_name, "{any}", .{err});
    return die(1, self_name, "unable to get the log name.", .{});
}
fn loginuid() ?usize {
    var f = std.fs.openFileAbsoluteZ("/proc/self/loginuid", .{}) catch return null;
    defer f.close();
    var buf: [16]u8 = undefined;
    const r = f.read(&buf) catch return null;
    return std.fmt.parseInt(usize, buf[0..r], 0) catch return null;
}
