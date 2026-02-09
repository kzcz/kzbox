const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "sleep" ++ lib.orCommon("sleep");
pub const desc: []const u8 = "Sleep. ";
const mem_eql = lib.mem_eql;
const Parser = argp.Gen(argp.std_vh, .{}, .{ .usage = usage, .desc = desc });
const linux = std.os.linux;
const TsInt = @typeInfo(linux.timespec).@"struct".fields[0].type;
const ns2s = 1_000_000_000;
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
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
            .positional => break,
            else => unreachable,
        }
    } else |_| {
        try parser.printLastError(eout);
        return 1;
    }
    const iargs = args[parser.idx..args.len];
    if (iargs.len == 0) Parser.dieMissingArguments(eout);
    var l = try std.ArrayList(linux.timespec).initCapacity(alloc, 4);
    defer l.deinit(alloc);
    try l.append(alloc, .{ .sec = 0, .nsec = 0 });
    const imax = std.math.maxInt(TsInt);
    for (0.., iargs) |idx, arg| {
        const ts = parseTimespec(arg) catch |err| root.die(1, "\"{s}\" (argument #{d}): {s}", .{ arg, idx, switch (err) {
            error.InvalidCharacter => "Invalid character.",
            error.Overflow => "Value too long.",
            error.TooLong => "Fractional part too long.",
            else => unreachable,
        } });
        const last = &l.items[l.items.len - 1];
        if (last.sec > imax - ts.sec) {
            const nsec = last.nsec + ts.nsec;
            const carry: linux.timespec = .{ .sec = last.sec - (imax - ts.sec) + @divFloor(nsec, ns2s), .nsec = @mod(nsec, ns2s) };
            last.sec = imax;
            last.nsec = 0;
            try l.append(alloc, carry);
        } else {
            last.nsec += ts.nsec; // Even on 32-bit systems, can't overflow
            last.sec += ts.sec + @divFloor(last.nsec, ns2s);
            last.nsec = @mod(last.nsec, ns2s);
        }
    }
    for (l.items) |times| {
        sleep(times);
    }
    return 0;
}
fn sleep(spec: linux.timespec) void {
    var req = spec;
    var rem: linux.timespec = undefined;
    while (true) {
        switch (linux.E.init(linux.clock_nanosleep(.MONOTONIC, .{ .ABSTIME = false }, &req, &rem))) {
            .SUCCESS => return,
            .INTR => {
                req = rem;
                continue;
            },
            .FAULT, .INVAL, .OPNOTSUPP => unreachable,
            else => return,
        }
    }
}
pub fn parseTimespec(input: []const u8) !linux.timespec {
    var result = linux.timespec{ .sec = 0, .nsec = 0 };
    var s = input;
    while (s.len > 0) {
        var has_dot = false;
        var dot_pos: usize = 0;
        var int_end: usize = 0;
        var i: usize = 0;
        while (i < s.len) {
            const c = s[i];
            if (c >= '0' and c <= '9') {
                if (!has_dot) int_end = i + 1;
                i += 1;
            } else if (c == '.') {
                if (has_dot) return error.InvalidCharacter;
                has_dot = true;
                dot_pos = i;
                int_end = i;
                i += 1;
            } else break;
        }
        if (i == 0) return error.InvalidCharacter;
        if (has_dot) {
            const frac_len = i - dot_pos - 1;
            if (frac_len == 0) return error.InvalidCharacter;
            if (frac_len > 8) return error.TooLong;
            if (dot_pos > 19) return error.Overflow;
        } else {
            if (int_end == 0) return error.InvalidCharacter;
            if (int_end > 19) return error.Overflow;
        }
        const num_end = i;
        var suffix_len: usize = 0;
        const suffix = if (i < s.len) sufs: {
            if (i + 1 < s.len and mem_eql(s[i .. i + 2], "ms")) {
                suffix_len = 2;
                break :sufs s[i .. i + 2];
            } else switch (s[i]) {
                's', 'm', 'h', 'd' => {
                    suffix_len = 1;
                    break :sufs s[i .. i + 1];
                },
                else => return error.InvalidCharacter,
            }
        } else @as([]const u8, "s");
        i += suffix_len;
        if (has_dot) {
            const value = try std.fmt.parseFloat(f64, s[0..num_end]);
            if (mem_eql(suffix, "ms")) {
                result.sec += @intFromFloat(@floor(value / 1000.0));
                result.nsec += @intFromFloat(@mod(value, 1000.0) * 1_000_000.0);
            } else {
                const scaled = @as(f64, switch (suffix[0]) {
                    's' => 1.0,
                    'm' => 60.0,
                    'h' => 3600.0,
                    'd' => 86400.0,
                    else => return error.InvalidCharacter,
                }) * value;
                result.sec += @intFromFloat(@floor(scaled));
                result.nsec += @intFromFloat(@round((scaled - @floor(scaled)) * 1_000_000_000.0));
            }
        } else {
            const value = try std.fmt.parseUnsigned(TsInt, s[0..int_end], 10);
            if (mem_eql(suffix, "ms")) {
                result.sec += @divFloor(value, 1000);
                result.nsec += @mod(value, 1000) * 1_000_000;
            } else result.sec += value * @as(TsInt, switch (suffix[0]) {
                's' => 1,
                'm' => 60,
                'h' => 3600,
                'd' => 86400,
                else => return error.InvalidCharacter,
            });
        }
        if (result.nsec >= ns2s) {
            const extra_sec = @divFloor(result.nsec, ns2s);
            result.sec += extra_sec;
            result.nsec = @mod(result.nsec, ns2s);
        } else if (result.nsec < 0) {
            const borrow = @divFloor(result.nsec, ns2s);
            result.sec += borrow;
            result.nsec -= borrow * ns2s;
        }
        s = s[i..];
    }
    return result;
}
