const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const pass_module = b.addModule("pass", .{ .source_file = .{ .path = "src/main.zig" } });

    {
        const example_hello_world = b.addExecutable(.{
            .name = "example-hello_world",
            // In this case the main source file is merely a path, however, in more
            // complicated build scripts, this could be a generated file.
            .root_source_file = .{ .path = "examples/hello_world.zig" },
            .target = target,
            .optimize = optimize,
        });
        example_hello_world.addModule("pass", pass_module);
        b.installArtifact(example_hello_world);
    }

    {
        const example_https_webserver = b.addExecutable(.{
            .name = "example-https_webserver",
            // In this case the main source file is merely a path, however, in more
            // complicated build scripts, this could be a generated file.
            .root_source_file = .{ .path = "examples/https_webserver.zig" },
            .target = target,
            .optimize = optimize,
        });
        example_https_webserver.addModule("pass", pass_module);
        b.installArtifact(example_https_webserver);
    }

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
