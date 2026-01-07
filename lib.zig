const std = @import("std");
const root = @import("root");
const sbt = std.builtin.Type;
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
        allow_intermix: bool,
    };
    pub fn EnumToList(Enum: type, Data: type) type {
        const ti = @typeInfo(Enum);
        assert(ti == .@"enum", "expected an enum, got " ++ @typeName(Enum));
        const enum_fields = @typeInfo(Enum).@"enum".fields;
        var fields: [enum_fields.len]sbt.StructField = undefined;
        inline for (&fields, enum_fields) |*e, f| e.* = .{ .is_comptime = false, .name = f.name, .type = Data, .alignment = @alignOf(Data), .default_value_ptr = null };
        return @Type(.{ .@"struct" = .{ .is_tuple = false, .layout = .auto, .decls = &.{}, .fields = &fields } });
    }
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
    pub fn val(name: [:0]const u8, has_args: bool, help: []const u8) Arg {
        return .{ .name = name, .has_args = has_args, .help = help };
    }
    pub fn Gen(comptime arg_tuple: anytype, comptime _config: Config) type {
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
                    if (std.mem.eql(u8, arg.name, str)) return i;
                }
                return null;
            }
            pub fn printLastError(self: *@This(), w: *std.Io.Writer, arg0: [:0]const u8) std.Io.Writer.Error!void {
                return (self.__err orelse return).print(w, arg0);
            }
            pub inline fn help_printer(comptime msg: []const u8, w: *std.Io.Writer) !void {
                const names = comptime blk: {
                    var ls: [args.len][:0]const u8 = undefined;
                    for (0.., args) |i, arg| ls[i] = arg.name;
                    break :blk ls;
                };
                const longest = comptime names[findLongestSlice([:0]const u8, &names)].len;
                try w.writeAll("Synopsis: " ++ msg ++ "\nFlags: \n");
                inline for (args) |arg| {
                    const n = arg.name;
                    try w.writeAll(comptime ("\t" ++ (if (n.len > 1) "--" else "-") ++ n ++ " " ** (1 + longest - n.len) ++ "- " ++ arg.help ++ "\n"));
                }
                try w.writeAll("\nVersion: " ++ root.version ++ "\n");
                try w.flush();
            }
            pub fn nextArg(self: *@This()) Error!RT {
                if (self.idx >= self.feed.len) return .{ .eof = void{} };
                var next = self.feed[self.idx];
                var symbol: ?[]const u8 = null;
                errdefer |e| self.__err = .{ .err = e, .symbol = symbol.? };
                self.idx += 1;
                if (next.len == 0) return self.nextArg();
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
pub inline fn findStr(src: []const u8, buf: []const []const u8) ?usize {
    for (0..buf.len, buf) |i, v| {
        if (std.mem.eql(u8, src, v)) return i;
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
