const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Template = @import("Template.zig");
pub const Config = @import("Config.zig");

/// 所有来自下层的错误
pub const Error = Config.Error || Template.Error || Io.Dir.CreateDirPathError || Io.Dir.WriteFileError || error{
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
    dir.createDirPath(io, "src") catch |err| switch (err) {
        error.PathAlreadyExists => return error.ProjectAlreadyExists,
        else => |e| return e,
    };

    const replacements = [_]Template.Replacement{
        .{ .placeholder = "__NAME__", .value = metadata.name },
    };
    const template: Template = .{ .replacements = &replacements };

    for (Template.exe_files) |file| {
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
