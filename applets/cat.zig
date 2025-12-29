const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const help: []const u8 = "ConcATenate files.";
const Parser = argp.Gen(.{ val("u", false, "Flushes data as it is received instead."), val("version", false, "Print the version string."), val("help", false, "Print this help message.") }, .{ .allow_intermix = false });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
    const self_name = args[0];

    var reader_buf = try alloc.alloc(u8, 512);
    defer alloc.free(reader_buf);
    var always_flush: bool = false;

    const cwd = std.fs.cwd();
    var parser = Parser.init(if (args.len == 1) (&[1][:0]const u8{"-"}) else args[1..]);
    var failed: bool = false;
    var has_opened_files: bool = false;
    w: while (parser.nextArg()) |arg| {
        const f: []const u8 = blk: switch (arg) {
            .eof => {
                if (!has_opened_files) break :blk "-";
                break :w;
            },
            .flag => |f| switch (f) {
                .u => {
                    always_flush = true;
                    continue :w;
                },
                .help => {
                    try Parser.help_printer(help, out);
                    break :w;
                },
                .version => {
                    try out.print("Version: {s}\n", .{root.detailed_version});
                    break :w;
                },
                _ => unreachable,
            },
            .positional => |f| {
                has_opened_files = true;
                break :blk f;
            },
            else => unreachable,
        };
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
        failed = (blk: while (true) {
            count = file.read(reader_buf) catch break :blk true;
            if (count == 0) break :blk false;
            out.writeAll(reader_buf[0..count]) catch break :blk true;
            if (always_flush) out.flush() catch break :blk true;
        }) or failed;
        try out.flush();
    } else |_| {
        try parser.printLastError(eout, self_name);
        return 1;
    }
    return @intFromBool(failed);
}
