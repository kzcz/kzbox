const std = @import("std");
const root = @import("root");
const lib = @import("kzlib");
const argp = lib.arg_parser;
const val = argp.val;
pub const usage: []const u8 = "kfmt" ++ lib.orCommon("kfmt");
pub const desc: []const u8 = "Killed Formatter";
fn filterT(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .comptime_float, .comptime_int, .enum_literal, .error_set, .error_union, .@"fn", .@"opaque", .type, .undefined, .noreturn, .null, .array => true,
        else => false,
    };
}
const Transform = struct {
    name: []const u8,
    T: type,
    callback: *const anyopaque,
    tailing: ?u8,
    params: []const std.builtin.Type.Fn.Param,
    pub fn init(name: []const u8, comptime T: type, comptime callback: *const T) @This() {
        const ti = @typeInfo(T);
        lib.assert(ti == .@"fn", "Callback must be a function. Received type: " ++ @tagName(ti));
        lib.assert(ti.@"fn".return_type.? == []const u8, "Callback's return type must be a string.");
        const _params = ti.@"fn".params;
        lib.assert(_params[0].type == []const u8, "Callback's first arg must be a string.");
        const params = _params[1..];
        for (params) |p| {
            const pt = p.type.?;
            if (filterT(pt)) @compileError("Unacceptable type " ++ @typeName(pt) ++ " as function parameter.");
            const pti = @typeInfo(pt);
            if (pti == .pointer and (pti.pointer.child != u8 or pti.pointer.size != .slice or pti.pointer.sentinel() != null)) @compileError("Unacceptable pointer type " ++ @typeName(pt) ++ " as function parameter.");
            if (pti == .@"enum") {
                for (std.meta.fieldNames(pt)) |f| lib.assert(f.len == 1, "Enum " ++ @typeName(pt) ++ ": fields should be exactly 1 letter long: " ++ f);
            }
        }
        var tailing = 0;
        var count = true;
        for (1..params.len + 1) |_v| {
            const v = params.len - _v;
            const p = @typeInfo(params[v].type.?);
            if (p != .optional) {
                count = false;
                continue;
            }
            if (count) {
                tailing += 1;
            } else {
                var buf: [16]u8 = undefined;
                @compileError("Optional argument #" ++ (std.fmt.bufPrint(&buf, "{d}", .{v}) catch unreachable) ++ " is not pair of the tail.");
            }
        }
        return .{ .name = name, .T = T, .callback = @ptrCast(callback), .tailing = tailing, .params = params };
    }
};
const TokenIter = struct {
    feed: []const u8,
    pub const Tk = union(enum(u2)) {
        string: []const u8,
        char: u8,
        semi: void,
    };
    pub fn next(self: *@This()) error{UnclosedQuote}!?Tk {
        const f = self.feed;
        if (f.len == 0) return null;
        if (f[0] == ';') {
            self.feed = self.feed[1..];
            return .{ .semi = {} };
        }
        if (f[0] == '\'') {
            const end = std.mem.indexOfScalarPos(u8, f, 1, '\'') orelse return error.UnclosedQuote;
            self.feed = f[end + 1 ..];
            return .{ .string = f[1..end] };
        }
        self.feed = self.feed[1..];
        return .{ .char = f[0] };
    }
};
fn inspect(state: []const u8) []const u8 { // i | -'i'
    std.debug.print("{s}\n", .{state});
    return state;
}
fn longer(state: []const u8, text: []const u8, optional: ?enum { a, b }, opt_text: ?[]const u8, number: ?u64) []const u8 { // -'longer'
    std.debug.print("State: \"{s}\"\ntext: '{s}'\noptional: '{?s}'\nopt_text: '{?s}'\nnumber: {?d}\n", .{ state, text, if (optional) |o| @tagName(o) else null, opt_text, number });
    return state;
}
const transforms: []const Transform = &[_]Transform{ .init("i", @TypeOf(inspect), &inspect), .init("longer", @TypeOf(longer), &longer) };
const RSError = std.fmt.ParseIntError || error{ UnclosedQuote, EmptyInput, UnexpectedSemicolor, NotEnoughArguments, UnexpectedValue, NotFound, UnknownFunction };
fn tkToParam(comptime Param: type, tk: TokenIter.Tk) !Param {
    if (tk == .semi) return error.UnexpectedSemicolor;
    const ti = @typeInfo(Param);
    //if (filterT(Param)) @compileError("huh? " ++ @typeName(Param));
    if (comptime filterT(Param)) {
        @compileError("Unacceptable type " ++ @typeName(Param) ++ " as function parameter. PT:" ++ @tagName(@typeInfo(Param)));
    }
    return switch (ti) {
        .pointer => if (tk == .string) @ptrCast(tk.string) else if (tk == .char) @ptrCast(&tk.char) else error.UnexpectedValue,
        .optional => try tkToParam(ti.optional.child, tk),
        .@"enum" => blk: {
            if (tk != .char) break :blk error.UnexpectedValue;
            inline for (ti.@"enum".fields) |f| {
                if (f.name[0] == tk.char) break :blk @field(Param, f.name);
            }
            break :blk error.NotFound;
        },
        .int => blk: {
            if (tk != .string) break :blk error.UnexpectedValue;
            break :blk std.fmt.parseInt(Param, tk.string, 0);
        },
        .null, .noreturn, .undefined, .type, .@"opaque", .@"fn", .error_union, .error_set, .enum_literal, .comptime_int, .comptime_float, .array => error.UnexpectedValue,
        else => unreachable,
    };
}
fn run_string(it: *TokenIter, input: []const u8) RSError![]const u8 {
    var cmd: []const u8 = undefined;
    var fill_optional: bool = false;

    const res = try it.next() orelse return error.EmptyInput;
    switch (res) {
        .semi => return error.UnexpectedSemicolor,
        .char => |c| {
            if (c == '-') {
                const res2 = try it.next() orelse return error.EmptyInput;
                cmd = switch (res2) {
                    .semi => return error.UnexpectedSemicolor,
                    .char => @ptrCast(&res2.char),
                    .string => res2.string,
                };
                if (res2 == .char) fill_optional = true;
            } else cmd = @ptrCast(&res.char);
        },
        .string => |s| cmd = s,
    }
    inline for (transforms) |t| {
        if (lib.mem_eql(cmd, t.name)) {
            var tp: std.meta.ArgsTuple(t.T) = undefined;
            tp.@"0" = input;
            inline for (comptime std.meta.fieldNames(@TypeOf(tp))[1..], t.params) |n, argt| {
                const tailing = @typeInfo(argt.type.?) == .optional;
                if (fill_optional and tailing) {
                    @field(tp, n) = null;
                } else {
                    const tk: ?TokenIter.Tk = try it.next() orelse if (tailing) null else return error.NotEnoughArguments;
                    if (tk == null or tk.? == .semi) {
                        if (!tailing) return error.NotEnoughArguments;
                        fill_optional = true;
                        @field(tp, n) = null;
                    } else @field(tp, n) = try tkToParam(argt.type.?, tk.?);
                }
            }
            return @call(.auto, @as(*const t.T, @ptrCast(t.callback)).*, tp);
        }
    }
    std.debug.print("cmd: {s}\n", .{cmd});
    return error.UnknownFunction;
}
const Parser = argp.Gen(argp.std_vh, .{}, .{ .usage = usage, .desc = desc });
pub fn main(args: [][:0]u8) !u8 {
    const out = root.out;
    const eout = root.eout;
    const alloc = root.alloc;
    _ = alloc;
    var parser = Parser.init(args);
    const self_name = parser.argv0;
    _ = self_name;

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
            .positional => |f| {
                var it = TokenIter{ .feed = f };
                _ = try run_string(&it, "test");
            },
            else => unreachable,
        }
    } else |_| {
        try parser.printLastError(eout);
        return 1;
    }
    return 0;
}
