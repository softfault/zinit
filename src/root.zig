const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Template = @import("Template.zig");
pub const Config = @import("Config.zig");

/// 所有来自下层的错误
pub const Error = Config.Error || Template.Error || Io.RandomSecureError || Io.Dir.CreateDirPathError || Io.Dir.WriteFileError || error{
    ProjectAlreadyExists,
};

/// main context
pub const ProjectMetadata = struct {
    name: []const u8,
};

/// 主要流程 + 主要context
pub fn initExeProject(
    io: Io,
    allocator: Allocator,
    dir: Io.Dir,
    metadata: ProjectMetadata,
) Error!void {
    const package_name = try packageNameAlloc(allocator, metadata.name);
    defer allocator.free(package_name);
    const fingerprint = try fingerprintAlloc(io, allocator, package_name);
    defer allocator.free(fingerprint);

    const replacements = [_]Template.Replacement{
        .{ .placeholder = "__NAME__", .value = metadata.name },
        .{ .placeholder = "__PACKAGE_NAME__", .value = package_name },
        .{ .placeholder = "__FINGERPRINT__", .value = fingerprint },
        .{ .placeholder = "__ZIG_VERSION__", .value = builtin.zig_version_string },
    };
    const template: Template = .{ .replacements = &replacements };

    for (Template.exe_files) |file| {
        if (std.fs.path.dirname(file.path)) |dirname| {
            // createDirPath会递归的创建好文件以及对应的目录
            // 类似于`mkdir -p`
            try dir.createDirPath(io, dirname);
        }

        const rendered = try template.render(allocator, file.body);
        defer allocator.free(rendered);

        dir.writeFile(io, .{
            .sub_path = file.path,
            .data = rendered,
            .flags = .{ .exclusive = true },
        }) catch |err| switch (err) {
            // 任何一个file如果exist那么都会导致整个流程的中断，这是合理的
            // 防止出现中途生成部分文件的情况。
            // FIXME: 会有清理/恢复吗？
            error.PathAlreadyExists => return error.ProjectAlreadyExists,

            else => |e| return e,
        };
    }
}

/// 核心build.zig.zon fingerprint算法
fn fingerprintAlloc(io: Io, allocator: Allocator, package_name: []const u8) Error![]u8 {
    var bytes: [4]u8 = undefined;
    try io.randomSecure(&bytes);

    // zig 0.16.0的fingerprint为一个u64
    // 高32位为package name的CRC32
    // 低32位则为随机值
    const name_hash: u64 = std.hash.Crc32.hash(package_name);
    const random_part: u64 = std.mem.readInt(u32, &bytes, .little);
    const fingerprint = (name_hash << 32) | random_part;
    return std.fmt.allocPrint(allocator, "0x{x:0>16}", .{fingerprint});
}

/// 命名规范化
/// zig init会对名字做处理，而不是任意的文件夹名称都可以作为package name
fn packageNameAlloc(allocator: Allocator, name: []const u8) Error![]u8 {
    var package_name = try std.ArrayList(u8).initCapacity(allocator, name.len + 1);
    errdefer package_name.deinit(allocator);

    // 非indent 开头会被加_
    // 比如123-foo -> _123...
    if (name.len == 0 or !isIdentStart(name[0])) {
        try package_name.append(allocator, '_');
    }

    for (name) |byte| {
        // 非ascii数字或者字母的会被变成_
        try package_name.append(allocator, if (isIdentContinue(byte)) byte else '_');
    }

    return package_name.toOwnedSlice(allocator);
}

fn isIdentStart(byte: u8) bool {
    return byte == '_' or std.ascii.isAlphabetic(byte);
}

fn isIdentContinue(byte: u8) bool {
    return isIdentStart(byte) or std.ascii.isDigit(byte);
}
