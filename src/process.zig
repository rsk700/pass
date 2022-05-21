const std = @import("std");

pub const ExitCode = enum { success_on_exit, error_on_exit, fail_on_start };

pub const ProcessOutput = struct { stdout: std.ArrayList(u8), stderr: std.ArrayList(u8) };

pub const ProcessResult = struct {
    const Self = @This();
    code: ExitCode,
    output: ?ProcessOutput,

    pub fn failOnStart() Self {
        return ProcessResult{ .code = .fail_on_start, .output = null };
    }

    pub fn ok(self: *const Self) bool {
        return self.code == .success_on_exit;
    }

    pub fn deinit(self: *Self) void {
        if (self.output) |output| {
            output.stdout.deinit();
            output.stderr.deinit();
        }
        self.* = undefined;
    }
};

fn copySliceToArray(data: []const u8, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    var array = std.ArrayList(u8).init(allocator);
    for (data) |d| {
        try array.append(d);
    }
    return array;
}

pub fn runWithCheckedOutput(cmd: []const []const u8, allocator: std.mem.Allocator) ProcessResult {
    const proc = std.ChildProcess.init(cmd, allocator) catch return ProcessResult.failOnStart();
    defer proc.deinit();
    proc.stdout_behavior = .Pipe;
    proc.stderr_behavior = .Pipe;
    proc.spawn() catch return ProcessResult.failOnStart();
    const output_raw = proc.stdout.?.reader().readAllAlloc(allocator, std.math.maxInt(usize)) catch return ProcessResult.failOnStart();
    defer allocator.free(output_raw);
    const err_output_raw = proc.stderr.?.reader().readAllAlloc(allocator, std.math.maxInt(usize)) catch return ProcessResult.failOnStart();
    defer allocator.free(err_output_raw);
    const output = copySliceToArray(std.mem.trim(u8, output_raw, "\n "), allocator) catch return ProcessResult.failOnStart();
    const err_output = copySliceToArray(std.mem.trim(u8, err_output_raw, "\n "), allocator) catch return ProcessResult.failOnStart();
    const proc_term = proc.wait() catch return ProcessResult.failOnStart();
    switch (proc_term) {
        .Exited => |code| if (code == 0) {
            return ProcessResult{ .code = .success_on_exit, .output = .{ .stdout = output, .stderr = err_output } };
        } else {
            return ProcessResult{ .code = .error_on_exit, .output = .{ .stdout = output, .stderr = err_output } };
        },
        else => return ProcessResult.failOnStart(),
    }
}

test {
    const testing = std.testing;
    var result = runWithCheckedOutput(&[_][]const u8{ "echo", "1" }, std.testing.allocator);
    defer result.deinit();
    try testing.expect(std.mem.eql(u8, result.output.?.stdout.items, "1"));
    try testing.expect(std.mem.eql(u8, result.output.?.stderr.items, ""));
}
