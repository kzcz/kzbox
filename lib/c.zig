const std = @import("std");
const root = @import("root");
const mem_eql = @import("string.zig").mem_eql;
pub const UTmpX = @import("utmpx").utmpx;
pub fn UTmpIterator(UTmp: type) type {
    return struct {
        buf: UTmp align(8),
        file: std.Io.File,
        io: std.Io,
        pub fn init(io: std.Io) !@This() {
            if (!@import("builtin").link_libc) return error.LibCNotLinked;
            return .{ .file = try std.Io.Dir.openFileAbsolute(io, "/var/run/utmp", .{}), .buf = undefined, .io = io };
        }
        pub fn deinit(self: *@This()) void {
            self.file.close(self.io);
        }
        pub fn next(self: *@This()) !?UTmp {
            const ret = try self.file.readStreaming(self.io, &[_][]u8{@ptrCast(&self.buf)});
            if (ret == 0) return null;
            if (ret != @sizeOf(UTmp)) unreachable;
            return self.buf;
        }
    };
}

pub fn ttyname(buf: []u8) ![]const u8 {
    const nat = "not a tty";
    if (std.posix.system.isatty(0) > 0) {
        return buf[0..try std.Io.Dir.readLinkAbsolute(root.init.io, "/proc/self/fd/0", buf)];
    } else {
        if (buf.len < nat.len) return error.Overflow;
        @memcpy(buf[0..nat.len], nat);
        return buf[0..nat.len];
    }
}
pub fn loginuid(io: std.Io) !usize {
    var f = std.Io.Dir.openFileAbsolute(io, "/proc/self/loginuid", .{}) catch return error.LoginuidUnavailable;
    defer f.close(io);
    var buf: [16]u8 = undefined;
    const r = try f.readPositionalAll(io, &buf, 0);
    return std.fmt.parseInt(usize, buf[0..r], 0);
}
pub fn findTLogin(io: std.Io) !?[]const u8 {
    var name_buf: [64]u8 = undefined;
    const name = try ttyname(&name_buf);
    if (mem_eql(name, "not a tty")) return error.NotATTY;
    var utmp_iter = UTmpIterator(@import("utmpx").utmpx).init(io) catch unreachable;
    const name_wo_dev = name[5..name.len];
    while (try utmp_iter.next()) |ent| {
        if (ent.ut_type != 7) continue;
        if (mem_eql(ent.ut_line[0 .. std.mem.indexOfScalar(u8, &ent.ut_line, 0) orelse ent.ut_line.len], name_wo_dev)) return &ent.ut_user;
    }
    return null;
}
pub fn getlogin(io: std.Io) !?[]const u8 {
    const v = loginuid(io) catch return findTLogin(io);
    const pw = std.c.getpwuid(@intCast(v)) orelse return error.GetPwUid;
    const n = pw.name orelse return null;
    return std.mem.span(n);
}
