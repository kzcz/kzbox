const std = @import("std");
const mem_eql = @import("string.zig").mem_eql;
pub const UTmpX = @import("utmpx").utmpx;
pub fn UTmpIterator(UTmp: type) type {
    return struct {
        buf: UTmp,
        file: std.fs.File,
        pub fn init() !@This() {
            if (!@import("builtin").link_libc) return error.LibCNotLinked;
            return .{ .file = try std.fs.openFileAbsoluteZ("/var/run/utmp", .{}), .buf = undefined };
        }
        pub fn deinit(self: *@This()) void {
            self.file.close();
        }
        pub fn next(self: *@This()) !?UTmp {
            const ret = try self.file.read(@ptrCast(&self.buf));
            if (ret == 0) return null;
            if (ret != @sizeOf(UTmp)) unreachable;
            return self.buf;
        }
    };
}

pub fn ttyname(buf: []u8) ![]const u8 {
    const nat = "not a tty";
    if (std.posix.isatty(0)) {
        return buf[0..(try std.posix.readlink("/proc/self/fd/0", buf)).len];
    } else {
        if (buf.len < nat.len) return error.Overflow;
        @memcpy(buf[0..nat.len], nat);
        return buf[0..nat.len];
    }
}
pub fn loginuid() !usize {
    var f = std.fs.openFileAbsoluteZ("/proc/self/loginuid", .{}) catch return error.LoginuidUnavailable;
    defer f.close();
    var buf: [16]u8 = undefined;
    const r = try f.read(&buf);
    return std.fmt.parseInt(usize, buf[0..r], 0);
}
pub fn findTLogin() !?[]const u8 {
    var name_buf: [64]u8 = undefined;
    const name = try ttyname(&name_buf);
    if (mem_eql(name, "not a tty")) return error.NotATTY;
    var utmp_iter = UTmpIterator(@import("utmpx").utmpx).init() catch unreachable;
    const name_wo_dev = name[5..name.len];
    while (try utmp_iter.next()) |ent| {
        if (ent.ut_type != 7) continue;
        if (mem_eql(ent.ut_line[0 .. std.mem.indexOfScalar(u8, &ent.ut_line, 0) orelse ent.ut_line.len], name_wo_dev)) return &ent.ut_user;
    }
    return null;
}
pub fn getlogin() !?[]const u8 {
    const v = loginuid() catch return findTLogin();
    const pw = std.c.getpwuid(@intCast(v)) orelse return error.GetPwUid;
    const n = pw.name orelse return null;
    return std.mem.span(n);
}
