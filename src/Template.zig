const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

replacements: []const Replacement,

pub const Error = Allocator.Error;

pub const Replacement = struct {
    placeholder: []const u8,
    value: []const u8,
};

/// returns a rendered file that need to be free
pub fn render(
    self: *const @This(),
    allocator: Allocator,
    file_content: []const u8,
) Error![]u8 {
    var rendered = try allocator.dupe(u8, file_content);
    errdefer allocator.free(rendered);

    // 性能稍微有点烂
    // 要用很多次分配
    // arena?
    for (self.replacements) |replacement| {
        const next = try std.mem.replaceOwned(
            u8,
            allocator,
            rendered,
            replacement.placeholder,
            replacement.value,
        );
        allocator.free(rendered);
        rendered = next;
    }

    return rendered;
}

pub const File = struct {
    path: []const u8,
    body: []const u8,
};

pub const exe_files = [_]File{
    .{ .path = "build.zig", .body = BUILD_ZIG },
    .{ .path = "src/main.zig", .body = SRC_MAIN_ZIG },
    .{ .path = "src/root.zig", .body = SRC_ROOT_ZIG },
    .{ .path = ".gitignore", .body = GIT_IGNORE },
    .{ .path = "README.md", .body = README_MD },
};

/// `__NAME__`: name of the program & the folder
pub const BUILD_ZIG =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const target = b.standardTargetOptions(.{});
    \\    const optimize = b.standardOptimizeOption(.{});
    \\
    \\    const mod = b.addModule("__NAME__", .{
    \\        .root_source_file = b.path("src/root.zig"),
    \\        .target = target,
    \\    });
    \\
    \\    const exe = b.addExecutable(.{
    \\        .name = "__NAME__",
    \\        .root_module = b.createModule(.{
    \\            .root_source_file = b.path("src/main.zig"),
    \\            .target = target,
    \\            .optimize = optimize,
    \\            .imports = &.{
    \\                .{ .name = "__NAME__", .module = mod },
    \\            },
    \\        }),
    \\    });
    \\
    \\    b.installArtifact(exe);
    \\
    \\    const run_step = b.step("run", "Run the app");
    \\    const run_cmd = b.addRunArtifact(exe);
    \\
    \\    run_step.dependOn(&run_cmd.step);
    \\    run_cmd.step.dependOn(b.getInstallStep());
    \\
    \\    if (b.args) |args| {
    \\        run_cmd.addArgs(args);
    \\    }
    \\
    \\    const mod_tests = b.addTest(.{
    \\        .root_module = mod,
    \\    });
    \\    const run_mod_tests = b.addRunArtifact(mod_tests);
    \\    const exe_tests = b.addTest(.{
    \\        .root_module = exe.root_module,
    \\    });
    \\    const run_exe_tests = b.addRunArtifact(exe_tests);
    \\
    \\    const test_step = b.step("test", "Run tests");
    \\    test_step.dependOn(&run_mod_tests.step);
    \\    test_step.dependOn(&run_exe_tests.step);
    \\}
    \\
;

/// `__NAME__`: name of the program & the folder
pub const SRC_MAIN_ZIG =
    \\const std = @import("std");
    \\const Io = std.Io;
    \\
    \\const __NAME__ = @import("__NAME__");
    \\
    \\pub fn main(init: std.process.Init) !void {
    \\    const arena = init.arena.allocator();
    \\    const args = try init.minimal.args.toSlice(arena);
    \\
    \\    const io = init.io;
    \\
    \\    var stdout_buffer: [1024]u8 = undefined;
    \\    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    \\    const stdout = &stdout_file_writer.interface;
    \\
    \\    var stderr_buffer: [1024]u8 = undefined;
    \\    var stderr_file_writer: Io.File.Writer = .init(.stderr(), io, &stderr_buffer);
    \\    const stderr = &stderr_file_writer.interface;
    \\
    \\    const gpa = init.gpa;
    \\    const code = run(io, gpa, args, stdout) catch |err|
    \\        try handleRunError(stderr, err);
    \\
    \\    try stdout_file_writer.flush();
    \\    try stderr_file_writer.flush();
    \\
    \\    std.process.exit(code);
    \\}
    \\
    \\pub fn run(
    \\    io: Io,
    \\    allocator: std.mem.Allocator,
    \\    args: []const []const u8,
    \\    stdout: *Io.Writer,
    \\) __NAME__.Error!u8 {
    \\    _ = io;
    \\    _ = allocator;
    \\    _ = args;
    \\    _ = stdout;
    \\}
    \\
    \\fn handleRunError(stderr: *Io.Writer, err: __NAME__.Error) !u8 {
    \\    _ = stderr;
    \\    _ = err;
    \\}
    \\
;

pub const SRC_ROOT_ZIG =
    \\const std = @import("std");
    \\const Io = std.Io;
    \\const Allocator = std.mem.Allocator;
    \\
    \\const Error = error{};
    \\
;

pub const GIT_IGNORE =
    \\/.zig-cache/
    \\/zig-out/
    \\
;

/// `__NAME__`: name of the program & the folder
pub const README_MD =
    \\# __NAME__
    \\
;

test render {
    const replacements = [_]Replacement{
        .{ .placeholder = "__NAME__", .value = "demo" },
    };
    const template: @This() = .{ .replacements = &replacements };

    const rendered = try template.render(std.testing.allocator, "hello __NAME__");
    defer std.testing.allocator.free(rendered);

    try std.testing.expectEqualStrings("hello demo", rendered);
}
