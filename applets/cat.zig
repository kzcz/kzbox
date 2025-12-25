const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const help: []const u8 = "ConcATenate files.";
const Parser = argp.Gen(.{ val("u", false), val("version", false), val("help", false) }, .{ .allow_intermix = false });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
    const self_name = args[0];

    var reader_buf = try alloc.alloc(u8, 512);
    defer alloc.free(reader_buf);

    const cwd = std.fs.cwd();
    var parser = Parser.init(if (args.len == 0) &[_][:0]const u8{"-"} else args[1..]);
    var failed: bool = false;
    while (parser.nextArg()) |arg| {
        if (arg.source == null and arg.value == null) break;
        if (arg.source) |s| {
            switch (s) {
                .u => continue,
                .help => {
                    try lib.help_printer(Parser, .{ .u = "ignored", .version = "Print the version string", .help = "Print this help message" }, help, out);
                    break;
                },
                .version => {
                    try out.print("Version: {s}\n", .{root.detailed_version});
                    break;
                },
                _ => unreachable,
            }
        }
        const f = arg.value.?;
        var freal = true;
        var file = if (f.len == 1 and f[0] == '-') bl: {
            freal = false;
            break :bl std.fs.File.stdin();
        } else cwd.openFile(f, .{ .mode = .read_only }) catch |err| {
            try eout.print("{s}: {s}: {s}\n", .{ self_name, f, @errorName(err) });
            try eout.flush();
            failed = true;
            continue;
        };
        defer if (freal) file.close();
        var count: usize = undefined;
        while (true) {
            count = file.read(reader_buf) catch {
                failed = true;
                break;
            };
            out.writeAll(reader_buf[0..count]) catch {
                failed = true;
                break;
            };
            if (count == 0) break;
        }
        try out.flush();
    } else |_| {
        try parser.printLastError(eout, self_name);
        return 1;
    }
    return @intFromBool(failed);
}
