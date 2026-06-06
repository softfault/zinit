/// 一个简单的zig cli程序初始化器。
/// 内置了一套模板，并遵循和此项目同样的组织哲学。
const std = @import("std");
const Io = std.Io;

const zinit = @import("zinit");

/// 对于错误处理来说，如果错误发生在向stdout/stderr写入
/// 那么基本上也可以算是panic了，在不考虑某种嵌入式或者受限的前提下。
/// 除了向stdout/err写入发生的错误都应该被妥当处理，
/// 而不是依赖zig的裸报错
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    const stderr = &stderr_file_writer.interface;

    const gpa = init.gpa;
    const code = run(io, gpa, args, stdout) catch |err|
        try handleRunError(stderr, err);

    try stdout_file_writer.flush();
    try stderr_file_writer.flush();

    std.process.exit(code);
}

pub fn run(
    io: Io,
    allocator: std.mem.Allocator,
    args: []const []const u8,
    stdout: *Io.Writer,
) zinit.Error!u8 {
    const config = try zinit.Config.init(args);
    const project_name = try config.execute(io, allocator);
    defer allocator.free(project_name);

    // 实际上这个地方应该用一个Plan对象管理
    // 但是暂时这样写了
    try zinit.initExeProject(io, allocator, Io.Dir.cwd(), .{
        .name = project_name,
    });

    try stdout.print("initialized Zig project: {s}\n", .{project_name});
    return 0;
}

fn handleRunError(stderr: *Io.Writer, err: zinit.Error) !u8 {
    switch (err) {
        error.InvalidArgs => {
            try stderr.print("Usage: zinit [name]\n", .{});
            return 2;
        },
        error.ProjectAlreadyExists => {
            try stderr.print("error: project files already exist\n", .{});
            return 1;
        },
        error.OutOfMemory => {
            try stderr.print("error: out of memory\n", .{});
            return 1;
        },
        error.CurrentDirUnlinked => {
            try stderr.print("error: current directory no longer exists\n", .{});
            return 1;
        },
        error.AccessDenied, error.PermissionDenied => {
            try stderr.print("error: permission denied\n", .{});
            return 1;
        },
        error.NoSpaceLeft => {
            try stderr.print("error: no space left on device\n", .{});
            return 1;
        },
        else => {
            try stderr.print("error: {s}\n", .{@errorName(err)});
            return 1;
        },
    }
}
