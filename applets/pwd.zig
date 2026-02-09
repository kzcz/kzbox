const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "pwd [-PL]" ++ lib.orCommon("pwd");
pub const desc: []const u8 = "Print the current working directory.";
const Parser = argp.Gen(.{ val("L", false, "Output the logical path."), val("P", false, "Output the physical path.") } ++ argp.std_vh, .{}, .{ .usage = usage, .desc = desc });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    var flag: enum(u1) { L, P } = .L;
    var parser = Parser.init(args);
    while (parser.nextArg()) |arg| {
        switch (arg) {
            .eof => break,
            .flag => |f| {
                switch (f) {
                    .L => flag = .L,
                    .P => flag = .P,
                    .version => return lib.putVer(out),
                    .help => return Parser.help_printer(out),
                    else => unreachable,
                }
            },
            .positional => |f| root.die(1, "Unexpected operand: {s}", .{f}),
            else => unreachable,
        }
    } else |_| {
        try parser.printLastError(eout);
        return 1;
    }
    if (flag == .L) blk: {
        const env = std.posix.getenvZ("PWD") orelse break :blk;
        if (env.len > 4096 or env.len == 0 or env[0] != '/') break :blk;
        var penv: []const u8 = env;
        while (true) {
            const slash = if (std.mem.indexOfScalar(u8, penv[1..penv.len], '/')) |v| v + 1 else penv.len;
            const path = penv[1..slash];
            if (lib.mem_eql(path, ".") or lib.mem_eql(path, "..")) break :blk;
            penv = penv[slash..penv.len];
            if (penv.len == 0) break;
        }
        try out.print("{s}\n", .{env});
        try out.flush();
        return 0;
    }
    var outbuf: [4096]u8 = undefined;
    var path: []const u8 = std.posix.getcwd(&outbuf) catch |err| root.dieErr(1, "getcwd", err);
    path = lib.scalarTrimEnd(path, '/');
    path = if (path.len == 0) "/" else path;
    try out.print("{s}\n", .{path});
    try out.flush();
    return 0;
}
