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

/// 不要在这里的.path写目录
/// 确保都是文件
pub const exe_files = [_]File{
    .{ .path = "build.zig", .body = BUILD_ZIG },
    .{ .path = "build.zig.zon", .body = BUILD_ZIG_ZON },
    .{ .path = "src/main.zig", .body = SRC_MAIN_ZIG },
    .{ .path = "src/root.zig", .body = SRC_ROOT_ZIG },
    .{ .path = ".gitignore", .body = GIT_IGNORE },
    .{ .path = "README.md", .body = README_MD },
};

/// `__PACKAGE_NAME__`: importable package name
/// `__NAME__`: name of the program & the folder
pub const BUILD_ZIG =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const target = b.standardTargetOptions(.{});
    \\    const optimize = b.standardOptimizeOption(.{});
    \\
    \\    const mod = b.addModule("__PACKAGE_NAME__", .{
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
    \\                .{ .name = "__PACKAGE_NAME__", .module = mod },
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

/// `__PACKAGE_NAME__`: package name as a Zig enum literal
/// `__FINGERPRINT__`: generated package fingerprint
/// `__ZIG_VERSION__`: minimum Zig version
pub const BUILD_ZIG_ZON =
    \\.{
    \\    .name = .__PACKAGE_NAME__,
    \\    .version = "0.0.0",
    \\    .fingerprint = __FINGERPRINT__, // Changing this has security and trust implications.
    \\    .minimum_zig_version = "__ZIG_VERSION__",
    \\    .dependencies = .{},
    \\    .paths = .{
    \\        "build.zig",
    \\        "build.zig.zon",
    \\        "src",
    \\        "README.md",
    \\        ".gitignore",
    \\    },
    \\}
    \\
;

/// `__PACKAGE_NAME__`: importable package name
pub const SRC_MAIN_ZIG =
    \\const std = @import("std");
    \\const Io = std.Io;
    \\
    \\const app = @import("__PACKAGE_NAME__");
    \\
    \\pub fn main(init: std.process.Init) !void {
    \\    const io = init.io;
    \\
    \\    var stdout_buffer: [1024]u8 = undefined;
    \\    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    \\    const stdout = &stdout_file_writer.interface;
    \\
    \\    try run(stdout);
    \\    try stdout_file_writer.flush();
    \\}
    \\
    \\pub fn run(stdout: *Io.Writer) !void {
    \\    try app.hello(stdout);
    \\}
    \\
;

pub const SRC_ROOT_ZIG =
    \\const std = @import("std");
    \\const Io = std.Io;
    \\
    \\pub fn hello(stdout: *Io.Writer) !void {
    \\    try stdout.print("Hello, __NAME__!\n", .{});
    \\}
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
