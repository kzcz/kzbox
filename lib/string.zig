const std = @import("std");
pub inline fn mem_eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
pub inline fn findStr(src: []const u8, buf: []const []const u8) ?usize {
    for (0..buf.len, buf) |i, v| {
        if (mem_eql(src, v)) return i;
    } else return null;
}
pub inline fn findLongestSlice(comptime T: type, buf: []const T) usize {
    var best_len: usize = 0;
    var best_idx: usize = 0;
    for (0.., buf) |i, el| {
        if (el.len > best_len) {
            best_len = el.len;
            best_idx = i;
        }
    }
    return best_idx;
}
pub fn properPosixBasename(path: []const u8) []const u8 {
    if (path.len == 0) return ".";
    const only_slash = blk: {
        for (path) |b| {
            if (b != '/') break :blk false;
        }
        break :blk true;
    };
    if (only_slash) return path[0..1];
    return std.fs.path.basenamePosix(path);
}
pub fn removeSuffix(str: []const u8, suffix: []const u8) []const u8 {
    return if (std.mem.endsWith(u8, str, suffix)) str[0 .. str.len - suffix.len] else str;
}
pub fn scalarTrimStart(str: []const u8, scalar: u8) []const u8 {
    var shift: usize = 0;
    if (str.len == 0) return str;
    while (str[shift] == scalar) {
        shift += 1;
        if (shift == str.len) return str[0..0];
    }
    return str[shift..str.len];
}
pub fn scalarTrimEnd(str: []const u8, scalar: u8) []const u8 {
    if (str.len == 0) return str;
    var lim: usize = str.len - 1;
    while (str[lim] == scalar) {
        if (lim == 0) return str[0..0];
        lim -= 1;
    }
    return str[0 .. lim + 1];
}
pub fn scalarTrim(str: []const u8, scalar: u8) []const u8 {
    return scalarTrimEnd(scalarTrimStart(str, scalar), scalar);
}
