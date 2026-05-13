const std = @import("std");
const blt = @import("builtin");
const lib = @import("kzlib");
const _apts = @import("applets.zig");
pub var alloc = std.heap.smp_allocator;
pub var out: *std.Io.Writer = undefined;
pub var eout: *std.Io.Writer = undefined;
pub const version = @import("build.zig.zon").version;
pub const detailed_version = version ++ " zig " ++ blt.zig_version_string ++ " os " ++ @tagName(blt.os.tag) ++ " cpu " ++ @tagName(blt.cpu.arch) ++ " " ++ blt.cpu.model.name;
pub var self_name: [:0]const u8 = "kzbox";
pub var init: std.process.Init = undefined;
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
fn str_lt(_: @TypeOf(void), aa: Applet, ba: Applet) bool {
    const a, const b = .{ aa.name, ba.name };
    if (a.len != b.len) return a.len < b.len;
    for (a, b) |e, f| if (e != f) return e < f;
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
    if (name.len >= indexes.len) return null;
    const start = indexes[name.len] orelse return null;
    for (applets[start..applets.len]) |a| {
        if (a.name.len != name.len) break;
        if (lib.mem_eql(name, a.name)) return a;
    }
    return null;
}
pub fn main(_init: std.process.Init) !u8 {
    init = _init;
    var wo_buf: [512]u8 = undefined;
    var we_buf: [512]u8 = undefined;
    var wo = std.Io.File.stdout().writer(init.io, &wo_buf);
    var we = std.Io.File.stderr().writer(init.io, &we_buf);
    out = &wo.interface;
    eout = &we.interface;
    const help_fun = comptime resolve_applet("help").?.main;
    defer out.flush() catch unreachable;
    defer eout.flush() catch unreachable;
    const args = blk: {
        const len = init.minimal.args.vector.len;
        const args = try alloc.alloc([:0]u8, len);
        var it = try init.minimal.args.iterateAllocator(alloc);
        defer it.deinit();
        var i: usize = 0;
        while (it.next()) |next| {
            args[i] = try alloc.dupeSentinel(u8, next, 0);
            i += 1;
        }
        break :blk args;
    };
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
        fed_args[0] = try alloc.dupeSentinel(u8, bname, 0);
        self_name = fed_args[0];
    }
    if (std.mem.eql(u8, bname, "--version")) return lib.putVer(eout);
    if (std.mem.eql(u8, bname, "kzbox")) {
        var mock_args = try alloc.alloc([:0]u8, 1);
        mock_args[0] = try alloc.dupeSentinel(u8, "help", 0);
        self_name = mock_args[0];
        return help_fun(mock_args) catch |err| dieErr(1, null, err);
    }
    self_name = try alloc.dupeSentinel(u8, bname, 0);
    if (resolve_applet(bname)) |applet| return applet.main(fed_args) catch |err| dieErr(1, null, err);
    die(1, "Applet not found", .{});
}
