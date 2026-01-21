const std = @import("std");
const root = @import("root");
pub const usage: []const u8 = "help [applets...]";
pub const desc: []const u8 = "Provides usage information of the provided applets, or lists available applets when they're not provided.";
pub fn main(args: [][:0]u8) !u8 {
    var out = root.out;
    var _args = args;
    defer out.flush() catch unreachable;
    if (std.mem.eql(u8, _args[0], "help")) {
        _args = _args[1..];
    }
    if (_args.len == 0) {
        try out.writeAll("Available applets: ");
        for (root.applets) |_applet| {
            try out.writeAll(_applet.name);
            try out.writeByte(' ');
        }
        try out.writeByte('\n');
    }
    for (_args) |applet_name| {
        for (root.applets) |_applet| {
            if (std.mem.eql(u8, _applet.name, applet_name)) {
                try out.print("Help for {s}:\n\tUsage: {s}\n\tDescription: {s}\n\n", .{ applet_name, _applet.usage, _applet.desc });
                break;
            }
        } else {
            try out.print("Applet {s} not found.\n", .{applet_name});
        }
    }
    return 0;
}
