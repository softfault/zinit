const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

mode: InitMode,
name: ?[]const u8,
kind: TemplateKind,

pub const InitMode = enum {
    current_dir,
    new_dir,
};

pub const TemplateKind = enum {
    exe,
};

pub const Error = error{
    InvalidArgs,
} || Allocator.Error || std.process.CurrentPathError;

pub fn init(args: []const []const u8) Error!@This() {
    return switch (args.len) {
        1 => .{
            .mode = .current_dir,
            .name = null,
            .kind = .exe,
        },
        2 => .{
            .mode = .new_dir,
            .name = args[1],
            .kind = .exe,
        },
        else => error.InvalidArgs,
    };
}

/// 返回的字符串是拥有所有权的
pub fn execute(
    self: *const @This(),
    io: Io,
    allocator: Allocator,
) Error![]const u8 {
    return switch (self.mode) {
        .current_dir => try cwdNameAlloc(io, allocator),
        .new_dir => try allocator.dupe(u8, self.name.?),
    };
}

fn cwdNameAlloc(io: Io, allocator: Allocator) Error![]u8 {
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path_len = try std.process.currentPath(io, &path_buffer);
    const name = std.fs.path.basename(path_buffer[0..path_len]);
    return allocator.dupe(u8, name);
}
