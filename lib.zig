const std = @import("std");
const root = @import("root");
const blt = @import("builtin");
const lib_string = @import("lib/string.zig");
const lib_c = @import("lib/c.zig");

pub extern "c" fn strerror(c_int) [*:0]const u8;
const sbt = std.builtin.Type;
pub const mem_eql = lib_string.mem_eql;
pub const findStr = lib_string.findStr;
pub const findLongestSlice = lib_string.findLongestSlice;
pub const properPosixBasename = lib_string.properPosixBasename;
pub const removeSuffix = lib_string.removeSuffix;
pub const scalarTrimStart = lib_string.scalarTrimStart;
pub const scalarTrimEnd = lib_string.scalarTrimEnd;
pub const scalarTrim = lib_string.scalarTrim;
pub const UTmpIterator = lib_c.UTmpIterator;
pub const ttyname = lib_c.ttyname;
pub const loginuid = lib_c.loginuid;
pub const findTLogin = lib_c.findTLogin;
pub const getlogin = lib_c.getlogin;

pub inline fn orCommon(comptime name: []const u8) []const u8 {
    return "\n\tor " ++ name ++ " [--help | --version]";
}
pub fn putVer(w: *std.Io.Writer) !u8 {
    try w.writeAll("Version: " ++ root.detailed_version ++ "\n");
    try w.flush();
    return 0;
}
pub inline fn dieIfNotLibC(self_name: []const u8) void {
    if (!blt.link_libc) root.die(1, self_name, "Sorry, This program can not run when libc is not linked. Please recompile with libc so that you can use it.", .{});
}
pub inline fn assert(value: bool, comptime msg: []const u8) void {
    if (!value) @compileError(msg);
}
pub const arg_parser = struct {
    pub const Error = error{ NotFound, MissingValue, UnexpectedValue, AlreadyErrored };
    pub const ErrInfo = struct {
        err: Error,
        symbol: []const u8,
        pub fn print(self: *@This(), w: *std.Io.Writer, arg0: [:0]const u8) std.Io.Writer.Error!void {
            try w.print("{s}: ", .{arg0});
            try switch (self.err) {
                error.NotFound => w.print("Unknown argument '{s}'\n", .{self.symbol}),
                error.MissingValue => w.print("Missing value for argument '{s}'\n", .{self.symbol}),
                error.UnexpectedValue => w.print("Argument '{s}' received unexpected parameters.\n", .{self.symbol}),
                error.AlreadyErrored => w.writeAll("[[Unless you're the developer of this program and made a mistake, you shouldn't be reading this]] nextArg was called despite the previous call having returned an error\n"),
            };
            try w.flush();
        }
    };
    pub const Arg = struct { name: [:0]const u8, has_args: bool = false, help: []const u8 };
    pub const Config = struct {
        allow_intermix: bool = false,
        skip_empty: bool = false,
    };
    pub const Help = struct {
        usage: []const u8,
        desc: []const u8,
    };
    /// Convert a tuple of Args into a list of them.
    inline fn tupleToArgs(comptime args: anytype) []const Arg {
        const ti = @typeInfo(@TypeOf(args));
        assert(ti == .@"struct", "expected tuple, found" ++ @typeName(@TypeOf(args)));
        const tuple = ti.@"struct";
        assert(tuple.is_tuple, "expected tuple, found a regular struct");
        assert(tuple.fields.len >= 1, "tuple too short");
        const ret = comptime b: {
            var arg_list: [tuple.fields.len]Arg = undefined;
            for (&arg_list, tuple.fields) |*arg, f| {
                assert(f.type == Arg, "type of field " ++ f.name ++ " is not " ++ @typeName(Arg));
                arg.* = @field(args, f.name);
            }
            const final = arg_list;
            break :b final;
        };

        return &ret;
    }
    /// constructor of Arg
    pub fn val(name: [:0]const u8, has_args: bool, help: []const u8) Arg {
        return .{ .name = name, .has_args = has_args, .help = help };
    }
    pub fn Gen(comptime arg_tuple: anytype, comptime _config: Config, comptime _help: Help) type {
        const _args: []const Arg = tupleToArgs(arg_tuple);
        var efields: [_args.len]sbt.EnumField = undefined;
        for (0.., _args) |i, arg| efields[i] = sbt.EnumField{ .name = arg.name, .value = i };
        const PrivRTEnum: type = @Type(.{ .@"enum" = .{ .tag_type = u16, .decls = &[0]sbt.Declaration{}, .is_exhaustive = false, .fields = &efields } });
        return struct {
            parse: bool,
            feed: []const [:0]const u8,
            idx: u32,
            off: u32,
            __err: ?ErrInfo = null,
            /// Do not change
            config: Config,
            const args = _args;
            const help = _help;
            pub fn init(feed: []const [:0]const u8) @This() {
                return .{ .parse = true, .feed = feed, .idx = 0, .off = 0, .config = _config };
            }
            pub const RTEnum = PrivRTEnum;
            pub const RT = union(enum(u2)) {
                eof: void,
                positional: []const u8,
                flag: RTEnum,
                flag_args: struct { RTEnum, []const u8 },
            };
            pub fn getPos(str: []const u8) ?usize {
                for (0.., args) |i, arg| {
                    if (mem_eql(arg.name, str)) return i;
                }
                return null;
            }
            pub fn printLastError(self: *@This(), w: *std.Io.Writer, arg0: [:0]const u8) std.Io.Writer.Error!void {
                return (self.__err orelse return).print(w, arg0);
            }
            pub fn dieMissingArguments(w: *std.Io.Writer, name: [:0]const u8) noreturn {
                _ = help_printer(w) catch {};
                root.die(1, name, "Missing arguments", .{});
            }
            pub inline fn help_printer(w: *std.Io.Writer) !u8 {
                const names = comptime blk: {
                    var ls: [args.len][:0]const u8 = undefined;
                    for (0.., args) |i, arg| ls[i] = arg.name;
                    break :blk ls;
                };
                const longest = comptime names[findLongestSlice([:0]const u8, &names)].len;
                comptime var tw: []const u8 = "Usage: " ++ help.usage ++ "\nDescription: " ++ help.desc ++ "\nFlags: \n";
                inline for (args) |arg| {
                    const n = arg.name;
                    tw = tw ++ comptime ("\t" ++ (if (n.len > 1) "--" else "-") ++ n ++ " " ** (1 + longest - n.len) ++ "- " ++ arg.help ++ "\n");
                }
                tw = tw ++ "\nVersion: " ++ root.version ++ "\n";
                try w.writeAll(tw);
                try w.flush();
                return 0;
            }
            pub fn nextArg(self: *@This()) Error!RT {
                if (self.__err) |_| return error.AlreadyErrored;
                if (self.idx >= self.feed.len) return .{ .eof = void{} };
                var next = self.feed[self.idx];
                var symbol: ?[]const u8 = null;
                errdefer |e| self.__err = .{ .err = e, .symbol = symbol.? };
                self.idx += 1;
                if (next.len == 0) {
                    if (self.config.skip_empty) return self.nextArg();
                    self.parse = self.config.allow_intermix;
                    return .{ .positional = next };
                }
                if (!self.parse) return .{ .positional = next };
                if (self.off == 0) {
                    if (next[0] != '-' or next.len == 1) {
                        self.parse = self.config.allow_intermix;
                        return .{ .positional = next };
                    }
                    if (next[1] != '-') {
                        // short
                        const sn = next[1..2];
                        symbol = sn;
                        const source: RTEnum = @enumFromInt(getPos(sn) orelse return error.NotFound);
                        const arg = args[@intFromEnum(source)];
                        if (!arg.has_args) {
                            if (next.len != 2) {
                                self.off += 1;
                                self.idx -= 1;
                            }
                            return .{ .flag = source };
                        }
                        if (next.len == 2) {
                            if (self.idx >= self.feed.len) return error.MissingValue;
                            self.idx += 1;
                            return .{ .flag_args = .{ source, self.feed[self.idx - 1] } };
                        }
                        return .{ .flag_args = .{ source, next[2..next.len] } };
                    }
                    if (next.len == 2) {
                        self.parse = false;
                        return self.nextArg();
                    }
                    // long
                    if (next.len == 3) {
                        symbol = next;
                        return error.NotFound;
                    }
                    if (std.mem.indexOf(u8, next, "=")) |eq_idx| {
                        if (eq_idx - 2 < 2) {
                            symbol = next[2..eq_idx];
                            return error.NotFound;
                        }
                        const sn = next[2..eq_idx];
                        symbol = sn;
                        const source: RTEnum = @enumFromInt(getPos(sn) orelse return error.NotFound);
                        const arg = args[@intFromEnum(source)];
                        if (!arg.has_args) return error.UnexpectedValue;
                        if (next.len - eq_idx == 1) return error.MissingValue;
                        return .{ .flag_args = .{ source, next[eq_idx + 1 .. next.len] } };
                    }
                    const sn = next[2..];
                    symbol = sn;
                    const source: RTEnum = @enumFromInt(getPos(sn) orelse return error.NotFound);
                    const arg = args[@intFromEnum(source)];
                    if (!arg.has_args) {
                        return .{ .flag = source };
                    }
                    if (self.idx >= self.feed.len) return error.MissingValue;
                    self.idx += 1;
                    return .{ .flag_args = .{ source, self.feed[self.idx - 1] } };
                }
                const sn = next[self.off + 1 .. self.off + 2];
                symbol = sn;
                const source: RTEnum = @enumFromInt(getPos(sn) orelse return error.NotFound);
                const arg = args[@intFromEnum(source)];
                if (!arg.has_args) {
                    self.off += 1;
                    if (self.off + 1 >= next.len) {
                        self.off = 0;
                    } else {
                        self.idx -= 1;
                    }
                    return .{ .flag = source };
                }
                const t = self.off + 2;
                if (t >= next.len) {
                    if (self.idx >= self.feed.len) return error.MissingValue;
                    self.off = 0;
                    self.idx += 1;
                    return .{ .flag_args = .{ source, self.feed[self.idx - 1] } };
                }
                self.off = 0;
                return .{ .flag_args = .{ source, next[t..next.len] } };
            }
        };
    }
};
pub fn EnumToList(Enum: type, Data: type) type {
    const ti = @typeInfo(Enum);
    assert(ti == .@"enum", "expected an enum, got " ++ @typeName(Enum));
    const enum_fields = @typeInfo(Enum).@"enum".fields;
    var fields: [enum_fields.len]sbt.StructField = undefined;
    inline for (&fields, enum_fields) |*e, f| e.* = .{ .is_comptime = false, .name = f.name, .type = Data, .alignment = @alignOf(Data), .default_value_ptr = null };
    return @Type(.{ .@"struct" = .{ .is_tuple = false, .layout = .auto, .decls = &.{}, .fields = &fields } });
}

pub const MemInfo = struct {
    total: usize = 0,
    free: usize = 0,
    available: usize = 0,
    buffered: usize = 0,
    cached: usize = 0,
    sw_total: usize = 0,
    sw_free: usize = 0,
    unit_in_bytes: usize = 0,
};
const miFields = [_][]const u8{ "MemTotal", "MemFree", "MemAvailable", "Buffers", "Cached", "SwapTotal", "SwapFree" };
pub fn meminfo() !MemInfo {
    var rt: MemInfo = .{};
    var pmi = try std.fs.openFileAbsoluteZ("/proc/meminfo", .{});
    var buf: [3072]u8 = undefined;
    var info = switch (try pmi.read(&buf)) {
        0 => unreachable,
        else => |v| buf[0..v],
    };
    var unit: ?[]const u8 = null;
    while (std.mem.indexOfScalar(u8, info, '\n')) |newline| {
        const line = info[0..newline];
        info = info[newline + 1 .. info.len];
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse if (line.len < 2) break else return error.MalformedMemInfo;
        const field = line[0..colon];
        const _value = scalarTrimStart(line[colon + 1 .. line.len], ' ');
        if (field.len == 0 or _value.len == 0) return error.MalformedMemInfo;
        const space = std.mem.lastIndexOfScalar(u8, _value, ' ');
        const value = try std.fmt.parseInt(usize, _value[0 .. space orelse _value.len], 0);
        const c_unit: []const u8 = if (space) |s| _value[s + 1 .. _value.len] else "";
        const idx = findStr(field, &miFields) orelse continue;
        if (unit) |u| {
            if (!mem_eql(u, c_unit)) return error.MalformedMemInfo;
        } else {
            unit = c_unit;
            if (mem_eql(unit.?, "kB")) {
                rt.unit_in_bytes = 1024;
            } else return error.UnknownUnit;
        }
        @as(*usize, switch (idx) {
            0 => &rt.total,
            1 => &rt.free,
            2 => &rt.available,
            3 => &rt.buffered,
            4 => &rt.cached,
            5 => &rt.sw_total,
            6 => &rt.sw_free,
            else => unreachable,
        }).* = value;
    }
    return rt;
}
