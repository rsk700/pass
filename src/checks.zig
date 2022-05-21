const std = @import("std");
const Allocator = std.mem.Allocator;
const runWithCheckedOutput = @import("process.zig").runWithCheckedOutput;
const pass = @import("pass.zig");

pub const Check_AlwaysOk = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn yes(_: *const Self, _: Allocator) bool {
        return true;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

pub const Check_Constant = struct {
    const Self = @This();
    result: bool,

    pub fn init(result: bool) Self {
        return .{ .result = result };
    }

    pub fn yes(self: *const Self, _: Allocator) bool {
        return self.result;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test {
    const testing = @import("std").testing;
    {
        var always_ok = Check_AlwaysOk.init();
        var check = always_ok.as_Check();
        try testing.expect(check.yes(testing.allocator));
    }

    {
        var constant_true = Check_Constant.init(true);
        var check = constant_true.as_Check();
        try testing.expect(check.yes(testing.allocator));
    }

    {
        var constant_false = Check_Constant.init(false);
        var check = constant_false.as_Check();
        try testing.expect(!check.yes(testing.allocator));
    }
}

pub const Check_UserIsRoot = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn yes(_: *const Self, a: Allocator) bool {
        _ = a;
        return std.os.linux.geteuid() == 0;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

pub const Check_IsFile = struct {
    const Self = @This();
    path: []const u8,

    pub fn init(path: []const u8) Self {
        return .{ .path = path };
    }

    pub fn yes(self: *const Self, _: Allocator) bool {
        const file = std.fs.openFileAbsolute(self.path, .{ .read = true, .write = false, .lock = .None }) catch {
            return false;
        };
        defer file.close();
        const stat = file.stat() catch {
            return false;
        };
        return stat.kind == .File;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Check_IsFile" {
    const testing = @import("std").testing;
    const a = testing.allocator;
    {
        var check = Check_IsFile.init("/etc/fstab").as_Check();
        try testing.expect(check.yes(a));
    }
    {
        var check = Check_IsFile.init("/etc").as_Check();
        try testing.expect(!check.yes(a));
    }
    {
        var check = Check_IsFile.init("/random-non-existing-path").as_Check();
        try testing.expect(!check.yes(a));
    }
}

pub const Check_IsDir = struct {
    const Self = @This();
    path: []const u8,

    pub fn init(path: []const u8) Self {
        return .{ .path = path };
    }

    pub fn yes(self: *const Self, _: Allocator) bool {
        const file = std.fs.openFileAbsolute(self.path, .{ .read = true, .write = false, .lock = .None }) catch {
            return false;
        };
        defer file.close();
        const stat = file.stat() catch {
            return false;
        };
        return stat.kind == .Directory;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Check_IsDir" {
    const testing = @import("std").testing;
    const a = testing.allocator;
    {
        var check = Check_IsDir.init("/etc/fstab").as_Check();
        try testing.expect(!check.yes(a));
    }
    {
        var check = Check_IsDir.init("/etc").as_Check();
        try testing.expect(check.yes(a));
    }
    {
        var check = Check_IsDir.init("/random-non-existing-path").as_Check();
        try testing.expect(!check.yes(a));
    }
}

pub const Check_PathReadable = struct {
    const Self = @This();
    path: []const u8,

    pub fn init(path: []const u8) Self {
        return .{ .path = path };
    }

    pub fn yes(self: *const Self, _: Allocator) bool {
        const file = std.fs.openFileAbsolute(self.path, .{ .read = true, .write = false, .lock = .None }) catch {
            return false;
        };
        defer file.close();
        return true;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Check_PathReadable" {
    const testing = @import("std").testing;
    const a = testing.allocator;
    {
        var check = Check_PathReadable.init("/etc/fstab").as_Check();
        try testing.expect(check.yes(a));
    }
}

pub const Check_PathWritable = struct {
    const Self = @This();
    path: []const u8,

    pub fn init(path: []const u8) Self {
        return .{ .path = path };
    }

    pub fn yes(self: *const Self, _: Allocator) bool {
        const file = std.fs.openFileAbsolute(self.path, .{ .read = false, .write = true, .lock = .None }) catch {
            return false;
        };
        defer file.close();
        return true;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Check_PathWritable" {
    const testing = @import("std").testing;
    const a = testing.allocator;
    {
        var check = Check_PathWritable.init("/etc/fstab").as_Check();
        try testing.expect(!check.yes(a));
    }
}

pub const Named = struct {
    const Self = @This();
    name: []const u8,
    check: pass.Check,

    pub fn init(name: []const u8, check: pass.Check) Self {
        return .{ .name = name, .check = check };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        return self.check.yes(a);
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(self.name, self, yes);
    }
};

test "Named" {
    const testing = @import("std").testing;
    const expect = testing.expect;
    {
        const named = Named.init("new name", Check_AlwaysOk.init().as_Check()).as_Check();
        try expect(std.mem.eql(u8, named.name, "new name"));
    }
}

pub const Check_Not = struct {
    const Self = @This();
    check: pass.Check,

    pub fn init(check: pass.Check) Self {
        return .{ .check = check };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        return !self.check.yes(a);
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

pub const Check_Or = struct {
    const Self = @This();
    checks: []const pass.Check,

    pub fn init(checks: []const pass.Check) Self {
        return .{ .checks = checks };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        for (self.checks) |c| {
            if (c.yes(a)) {
                return true;
            }
        }
        return false;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

pub const Check_And = struct {
    const Self = @This();
    checks: []const pass.Check,

    pub fn init(checks: []const pass.Check) Self {
        return .{ .checks = checks };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        for (self.checks) |c| {
            if (!c.yes(a)) {
                return false;
            }
        }
        return true;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Checks boolean logic" {
    const testing = @import("std").testing;
    const a = testing.allocator;
    // Not
    {
        const not_true = Check_Not.init(Check_AlwaysOk.init().as_Check()).as_Check();
        try testing.expect(!not_true.yes(a));
    }
    {
        const not_false = Check_Not.init(Check_Constant.init(false).as_Check()).as_Check();
        try testing.expect(not_false.yes(a));
    }
    // Or
    {
        const true_or_true = Check_Or.init(&.{ Check_Constant.init(true).as_Check(), Check_Constant.init(true).as_Check() }).as_Check();
        try testing.expect(true_or_true.yes(a));
    }
    {
        const true_or_false = Check_Or.init(&.{ Check_Constant.init(true).as_Check(), Check_Constant.init(false).as_Check() }).as_Check();
        try testing.expect(true_or_false.yes(a));
    }
    {
        const false_or_false = Check_Or.init(&.{ Check_Constant.init(false).as_Check(), Check_Constant.init(false).as_Check() }).as_Check();
        try testing.expect(!false_or_false.yes(a));
    }
    // And
    {
        const true_and_true = Check_And.init(&.{ Check_Constant.init(true).as_Check(), Check_Constant.init(true).as_Check() }).as_Check();
        try testing.expect(true_and_true.yes(a));
    }
    {
        const true_and_false = Check_And.init(&.{ Check_Constant.init(true).as_Check(), Check_Constant.init(false).as_Check() }).as_Check();
        try testing.expect(!true_and_false.yes(a));
    }
    {
        const false_and_false = Check_And.init(&.{ Check_Constant.init(false).as_Check(), Check_Constant.init(false).as_Check() }).as_Check();
        try testing.expect(!false_and_false.yes(a));
    }
}

pub const Check_StdoutContainsOnce = struct {
    const Self = @This();
    cmd: []const []const u8,
    data: []const u8,

    pub fn init(cmd: []const []const u8, data: []const u8) Self {
        return .{ .cmd = cmd, .data = data };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        var result = runWithCheckedOutput(self.cmd, a);
        defer result.deinit();
        if (result.output) |out| {
            const index = if (std.mem.indexOf(u8, out.stdout.items, self.data)) |i| i else return false;
            // confirm there is only one match
            _ = std.mem.indexOfPos(u8, out.stdout.items, index + self.data.len, self.data) orelse return true;
        }
        return false;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Check_StdoutContainsOnce" {
    const testing = @import("std").testing;
    const expect = testing.expect;
    const a = testing.allocator;
    {
        const check = Check_StdoutContainsOnce.init(&.{ "echo", "abcaaa123" }, "aaa").as_Check();
        try expect(check.yes(a));
    }
    {
        const check = Check_StdoutContainsOnce.init(&.{ "echo", "abcaaa123aaa333" }, "aaa").as_Check();
        try expect(!check.yes(a));
    }
    {
        const check = Check_StdoutContainsOnce.init(&.{ "echo", "abcaaa123" }, "aaaa").as_Check();
        try expect(!check.yes(a));
    }
}

pub const Check_StderrContainsOnce = struct {
    const Self = @This();
    cmd: []const []const u8,
    data: []const u8,

    pub fn init(cmd: []const []const u8, data: []const u8) Self {
        return .{ .cmd = cmd, .data = data };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        var result = runWithCheckedOutput(self.cmd, a);
        defer result.deinit();
        if (result.output) |out| {
            const index = if (std.mem.indexOf(u8, out.stderr.items, self.data)) |i| i else return false;
            // confirm there is only one match
            _ = std.mem.indexOfPos(u8, out.stderr.items, index + self.data.len, self.data) orelse return true;
        }
        return false;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Check_StderrContainsOnce" {
    const testing = @import("std").testing;
    const expect = testing.expect;
    const a = testing.allocator;
    {
        const check = Check_StderrContainsOnce.init(&.{ "ls", "incorrect-path-abcaaa123" }, "aaa").as_Check();
        try expect(check.yes(a));
    }
    {
        const check = Check_StderrContainsOnce.init(&.{ "ls", "incorrect-path-abcaaa123aaa333" }, "aaa").as_Check();
        try expect(!check.yes(a));
    }
    {
        const check = Check_StderrContainsOnce.init(&.{ "ls", "incorrect-path-abcaaa123" }, "aaaa").as_Check();
        try expect(!check.yes(a));
    }
}

pub const Check_FileContent = struct {
    const Self = @This();
    path: []const u8,
    content: []const u8,

    pub fn init(path: []const u8, content: []const u8) Self {
        return .{ .path = path, .content = content };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        // todo: check file size equal content size first
        const content = b: {
            var file = std.fs.openFileAbsolute(self.path, .{ .read = true }) catch return false;
            defer file.close();
            break :b file.reader().readAllAlloc(a, std.math.maxInt(u64)) catch return false;
        };
        defer a.free(content);
        return std.mem.eql(u8, content, self.content);
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Check_FileContent" {
    const testing = @import("std").testing;
    const expect = testing.expect;
    const a = testing.allocator;
    const actions = @import("actions.zig");
    const path = "/tmp/testing_pass_check-file-content";
    {
        const write_file = actions.Action_WriteFile.init(path, "123abc").as_Action();
        try expect(write_file.run(a) == .ok);
        const check_content = Check_FileContent.init(path, "123abc").as_Check();
        try expect(check_content.yes(a));
        const check_incorrect_content = Check_FileContent.init(path, "kkk").as_Check();
        try expect(!check_incorrect_content.yes(a));
    }
}

pub const Check_FileContainsOnce = struct {
    const Self = @This();
    path: []const u8,
    target: []const u8,

    pub fn init(path: []const u8, target: []const u8) Self {
        return .{ .path = path, .target = target };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        const content = b: {
            var file = std.fs.openFileAbsolute(self.path, .{ .read = true }) catch return false;
            defer file.close();
            break :b file.reader().readAllAlloc(a, std.math.maxInt(u64)) catch return false;
        };
        defer a.free(content);
        const index = if (std.mem.indexOf(u8, content, self.target)) |i| i else return false;
        // confirm there is only one match
        _ = std.mem.indexOfPos(u8, content, index + self.target.len, self.target) orelse return true;
        return false;
    }

    pub fn as_Check(self: *const Self) pass.Check {
        return pass.Check.init(@typeName(Self), self, yes);
    }
};

test "Check_FileContainsOnce" {
    const testing = @import("std").testing;
    const expect = testing.expect;
    const a = testing.allocator;
    const actions = @import("actions.zig");
    const path = "/tmp/testing_pass_file-contains-once";
    {
        const write_file = actions.Action_WriteFile.init(path, "1223aaabc22").as_Action();
        try expect(write_file.run(a) == .ok);
        const check_match = Check_FileContainsOnce.init(path, "aaa").as_Check();
        try expect(check_match.yes(a));
        const check_incorrect_match = Check_FileContainsOnce.init(path, "bbb").as_Check();
        try expect(!check_incorrect_match.yes(a));
        const check_multiple_match = Check_FileContainsOnce.init(path, "22").as_Check();
        try expect(!check_multiple_match.yes(a));
    }
}