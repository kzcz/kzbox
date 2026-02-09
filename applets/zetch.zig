const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "zetch" ++ lib.orCommon("zetch");
pub const desc: []const u8 = "Z[ulfuric] fetch";
const Parser = argp.Gen(argp.std_vh, .{}, .{ .usage = usage, .desc = desc });
const W = *std.Io.Writer;
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
    _ = alloc;
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
            .positional => |f| root.die(1, "Unexpected operand: {s}", .{f}),
            else => unreachable,
        }
    } else |_| {
        try parser.printLastError(eout);
        return 1;
    }
    lib.dieIfNotLibC();
    const uname = rigUname();
    const sysinfo = rigSysinfo();
    try print_uname(out, uname);
    try print_loginfo(out, uname);
    // try print_ttysize
    try print_ram(out);
    try print_uptime(out, sysinfo.uptime);
    return 0;
}
const sys = std.os.linux;
const errno = std.posix.errno;
fn rigUname() sys.utsname {
    var uts: sys.utsname = undefined;
    switch (errno(sys.uname(&uts))) {
        .SUCCESS => return uts,
        else => unreachable,
    }
}
fn rigSysinfo() sys.Sysinfo {
    var inf: sys.Sysinfo = undefined;
    switch (errno(sys.sysinfo(&inf))) {
        .SUCCESS => return inf,
        else => unreachable,
    }
}

fn print_uname(w: W, uname: sys.utsname) !void {
    try w.print("{s} ({s}) for {s}\n", .{ uname.sysname, uname.release, uname.machine });
}
fn print_loginfo(w: W, uname: sys.utsname) !void {
    var ttybuf: [64]u8 = undefined;
    try w.print("{s}@{s}; Console: {s}\n", .{ (lib.getlogin() catch null) orelse "(unknown)", uname.nodename, lib.ttyname(&ttybuf) catch "(unknown tty)" });
}
fn t2T(t: anytype) @TypeOf(t) {
    return @as(@TypeOf(t), @intFromBool(t > 0));
}
fn print_uptime(w: W, ut: isize) !void {
    var _buf: [128]u8 = undefined;
    var buf = std.Io.Writer.fixed(&_buf);
    const d: isize = @divTrunc(ut, 86400);
    const h: isize = @mod(@divTrunc(ut, 3600), 24);
    const m: isize = @mod(@divTrunc(ut, 60), 60);
    const s: isize = @mod(ut, 60);
    var comps = t2T(h) + t2T(m) + t2T(s);
    if (d > 0) {
        try buf.print("{d} days{s}", .{ d, if (comps > 0) if (comps > 1) ", " else " and " else "" });
    }
    if (h > 0) {
        comps -= 1;
        try buf.print("{d} hours{s}", .{ h, if (comps > 0) if (comps > 1) ", " else " and " else "" });
    }
    if (m > 0) {
        comps -= 1;
        try buf.print("{d} minutes{s}", .{ m, if (comps > 0) " and " else "" });
    }
    if (s > 0) try buf.print("{d} seconds", .{s});
    try buf.writeByte('\n');
    try w.writeAll(buf.buffered());
}

fn print_ram(w: W) !void {
    const meminfo = try lib.meminfo();

    const MB = 1048576;
    const unit = meminfo.unit_in_bytes;

    const tr = (meminfo.total * unit) / MB;
    const tb_sw = (meminfo.sw_total * unit) / MB;
    const fr = (meminfo.available * unit) / MB;
    const ab_sw = (meminfo.sw_free * unit) / MB;

    const used_sw = tb_sw - ab_sw;
    const used = tr - fr;

    const total_f: f64 = @floatFromInt(tr);
    const pct_used = @trunc((@as(f64, @floatFromInt(used)) * 10000) / total_f) / 100;
    const pct_fr = @trunc((@as(f64, @floatFromInt(fr)) * 10000) / total_f) / 100;
    const ram_fmt = comptime "RAM:\tUsed (MB): {:6} / {:6} ({:>6.2}%)\n\tFree (MB):          {:6} ({:>6.2}%)\n";
    const ram_inp = .{ used, tr, pct_used, fr, pct_fr };

    const t_sw_f: f64 = @floatFromInt(tb_sw);
    const pct_used_sw = @trunc((@as(f64, @floatFromInt(used_sw)) * 10000) / t_sw_f) / 100;
    const pct_fr_sw = @trunc((@as(f64, @floatFromInt(ab_sw)) * 10000) / t_sw_f) / 100;
    const sw_fmt = comptime "SWAP:\tUsed (MB): {:6} / {:6} ({:>6.2}%)\n\tFree (MB):          {:6} ({:>6.2}%)\n";
    const sw_inp = .{ used_sw, tb_sw, pct_used_sw, t_sw_f, pct_fr_sw };

    try w.print(ram_fmt ++ sw_fmt, ram_inp ++ sw_inp);
}
