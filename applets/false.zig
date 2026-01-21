pub const usage: []const u8 = "false";
pub const desc: []const u8 = "Always returns 1.";
pub fn main(_: [][:0]u8) !u8 {
    return 1;
}
