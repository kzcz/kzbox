const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "cat [files...]" ++ lib.orCommon("cat");
pub const desc: []const u8 = "ConcATenate files.";
const Parser = argp.Gen(.{val("u", false, "Flushes data as it is received instead.")} ++ argp.std_vh, .{}, .{ .usage = usage, .desc = desc });
pub fn main(args: [][:0]u8) !u8 {
    const io = root.init.io;
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;

    var reader_buf = try alloc.alloc(u8, 512);
    defer alloc.free(reader_buf);
    var always_flush: bool = false;

    const cwd = std.Io.Dir.cwd();
    var parser = blk: {
        var a: []const [:0]const u8 = args;
        if (a.len == 1) {
            const mock_args = try alloc.alloc([:0]const u8, 2);
            mock_args[0] = args[0];
            mock_args[1] = "-";
            a = mock_args;
        }
        break :blk Parser.init(args);
    };
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
                .version => return lib.putVer(out),
                .help => return Parser.help_printer(out),
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
            break :bl std.Io.File.stdin();
        } else cwd.openFile(io, f, .{ .mode = .read_only }) catch |err| {
            try warn(eout, f, err);
            failed = true;
            continue;
        };
        defer if (freal) file.close(io);
        var count: usize = undefined;
        var f_reader = file.reader(io, &.{});
        var reader = &f_reader.interface;
        const last_err: ?anyerror = (blk: while (true) {
            count = reader.readSliceShort(reader_buf) catch |err| break :blk err;
            if (count == 0) break :blk null;
            out.writeAll(reader_buf[0..count]) catch |err| break :blk err;
            if (always_flush) out.flush() catch |err| break :blk err;
        });
        if (last_err) |err| {
            try warn(eout, f, err);
            failed = true;
        }
        try out.flush();
    } else |_| {
        try parser.printLastError(eout);
        return 1;
    }
    return @intFromBool(failed);
}
inline fn warn(w: *std.Io.Writer, file: []const u8, err: anyerror) !void {
    try w.print("{s}: {s}: {s}\n", .{ root.self_name, file, @errorName(err) });
    try w.flush();
}
