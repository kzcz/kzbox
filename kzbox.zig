const std = @import("std");
const blt = @import("builtin");
const lib = @import("kzlib");
const _apts = @import("applets.zig");
pub var alloc = std.heap.smp_allocator;
var wo_buf: [512]u8 = undefined;
var we_buf: [512]u8 = undefined;
var wo = std.fs.File.stdout().writer(&wo_buf);
var we = std.fs.File.stderr().writer(&we_buf);
pub var out: *std.io.Writer = &wo.interface;
pub var eout: *std.io.Writer = &we.interface;
pub const version = @import("build.zig.zon").version;
pub const detailed_version = version ++ " zig " ++ blt.zig_version_string ++ " os " ++ @tagName(blt.os.tag) ++ " cpu " ++ @tagName(blt.cpu.arch) ++ " " ++ blt.cpu.model.name;
pub var self_name: [:0]const u8 = "kzbox";
pub inline fn die(code: u8, comptime fmt: []const u8, args: anytype) noreturn {
    eout.writeAll(self_name) catch unreachable;
    eout.print(": " ++ fmt ++ "\n", args) catch unreachable;
    eout.flush() catch unreachable;
    std.process.exit(code);
}
pub inline fn dieErr(code: u8, tool_or_file: ?[]const u8, err: anyerror) noreturn {
    const name = @errorName(err);
    if (tool_or_file) |tof| die(code, "{s}: {s}", .{ tof, name });
    die(1, "{s}", .{name});
}
const Applet = _apts.Applet;
fn str_lt(ctx: @TypeOf(void), aa: Applet, ba: Applet) bool {
    _ = ctx;
    const a = aa.name;
    const b = ba.name;
    if (a.len != b.len) return a.len < b.len;
    for (a, b) |e, f| {
        if (e != f) return e < f;
    }
    return false;
}
pub const applets = blk: {
    var ret: [_apts._ap.len]Applet = undefined;
    for (0.., _apts._ap) |i, a| ret[i] = a;
    std.mem.sort(Applet, &ret, void, str_lt);
    const final = ret;
    break :blk @as([]const Applet, &final);
};
const indexes = blk: {
    var idxes: [applets[applets.len - 1].name.len + 1]?u8 = undefined;
    for (0..idxes.len) |i| idxes[i] = null;
    var cur: u8 = 0;
    for (0.., applets) |i, a| {
        const len: u8 = @intCast(a.name.len);
        if (cur == len) continue;
        cur = len;
        idxes[cur] = i;
    }
    break :blk idxes;
};
pub inline fn resolve_applet(name: []const u8) ?Applet {
    if (name.len > indexes.len) return null;
    const start = indexes[name.len] orelse return null;
    for (applets[start..applets.len]) |a| {
        if (a.name.len != name.len) break;
        if (lib.mem_eql(name, a.name)) return a;
    }
    return null;
}
pub fn main() !u8 {
    const help_fun = comptime resolve_applet("help").?.main;
    defer out.flush() catch unreachable;
    defer eout.flush() catch unreachable;
    const args = try std.process.argsAlloc(alloc);
    var fed_args = args;
    var bname: []u8 = undefined;
    for (0..args.len) |_| {
        bname = @constCast(std.fs.path.basename(fed_args[0]));
        for (0..bname.len) |i| bname[i] |= 0x20;
        if (!std.mem.eql(u8, bname, "kzbox")) break;
        fed_args = fed_args[1..];
    }
    if (std.mem.eql(u8, bname, "--help")) {
        bname = bname[2..bname.len];
        fed_args[0] = try alloc.dupeZ(u8, bname);
        self_name = fed_args[0];
    }
    if (std.mem.eql(u8, bname, "--version")) return lib.putVer(eout);
    if (std.mem.eql(u8, bname, "kzbox")) {
        var mock_args = try alloc.alloc([:0]u8, 1);
        mock_args[0] = try alloc.dupeZ(u8, "help");
        self_name = mock_args[0];
        return help_fun(mock_args) catch |err| dieErr(1, null, err);
    }
    self_name = try alloc.dupeZ(u8, bname);
    if (resolve_applet(bname)) |applet| return applet.main(fed_args) catch |err| dieErr(1, null, err);
    die(1, "Applet not found", .{});
}
