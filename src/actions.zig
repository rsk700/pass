const std = @import("std");
const Allocator = std.mem.Allocator;
const pass = @import("pass.zig");

pub fn named(comptime name: []const u8, comptime action: pass.Action) pass.Action {
    comptime {
        return Action_Named.init(name, action).as_Action();
    }
}

test "named" {
    _ = named("123", comptime Action_DoNothing.init().as_Action());
}

pub const Action_Named = struct {
    const Self = @This();
    name: []const u8,
    action: pass.Action,

    pub fn init(name: []const u8, action: pass.Action) Self {
        return .{ .name = name, .action = action };
    }

    pub fn run(self: *const Self, a: Allocator) pass.ActionResult {
        return self.action.run(a);
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(self.name, self, run);
    }
};

test {
    const testing = @import("std").testing;
    const expect = testing.expect;
    {
        const action_named = Action_Named.init("new name", Action_DoNothing.init().as_Action()).as_Action();
        try expect(std.mem.eql(u8, action_named.name, "new name"));
    }
}

pub fn doNothing() pass.Action {
    comptime {
        return Action_DoNothing.init().as_Action();
    }
}

test "doNothing" {
    _ = doNothing();
}

pub const Action_DoNothing = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn run(_: *const Self, _: Allocator) pass.ActionResult {
        return .ok;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

pub fn constant(comptime result: pass.ActionResult) pass.Action {
    comptime {
        return Action_Constant.init(result).as_Action();
    }
}

test "constant" {
    _ = constant(.ok);
}

pub const Action_Constant = struct {
    const Self = @This();
    result: pass.ActionResult,

    pub fn init(result: pass.ActionResult) Self {
        return .{ .result = result };
    }

    pub fn run(self: *const Self, _: Allocator) pass.ActionResult {
        return self.result;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

test {
    const testing = @import("std").testing;
    {
        var do_nothing = Action_DoNothing.init();
        const action = do_nothing.as_Action();
        try testing.expect(action.run(testing.allocator) == .ok);
    }

    {
        var const_fail = Action_Constant.init(.fail);
        const action = const_fail.as_Action();
        try testing.expect(action.run(testing.allocator) == .fail);
    }
}

pub fn many(comptime actions: []const pass.Action) pass.Action {
    comptime {
        return Action_Many.init(actions).as_Action();
    }
}

test "many" {
    _ = many(&.{comptime doNothing()});
}

pub const Action_Many = struct {
    const Self = @This();
    actions: []const pass.Action,

    pub fn init(actions: []const pass.Action) Self {
        return .{ .actions = actions };
    }

    pub fn run(self: *const Self, a: Allocator) pass.ActionResult {
        for (self.actions) |action| {
            const result = action.run(a);
            if (result != .ok) {
                return result;
            }
        }
        return .ok;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

test "Action_Many" {
    const testing = @import("std").testing;
    const a = testing.allocator;
    {
        const many_actions = Action_Many.init(&.{
            Action_DoNothing.init().as_Action(),
            Action_DoNothing.init().as_Action(),
        }).as_Action();
        try testing.expect(many_actions.run(a) == .ok);
    }
    {
        const last_fail = Action_Many.init(&.{
            Action_Constant.init(.ok).as_Action(),
            Action_Constant.init(.ok).as_Action(),
            Action_Constant.init(.fail).as_Action(),
        }).as_Action();
        try testing.expect(last_fail.run(a) == .fail);
    }
}

pub fn runProcess(comptime cmd: []const []const u8) pass.Action {
    comptime {
        return Action_RunProcess.init(cmd).as_Action();
    }
}

test "runProcess" {
    _ = runProcess(&.{"123"});
}

pub const Action_RunProcess = struct {
    const process = @import("process.zig");
    const Self = @This();
    cmd: []const []const u8,

    pub fn init(cmd: []const []const u8) Self {
        return .{ .cmd = cmd };
    }

    pub fn run(self: *const Self, a: Allocator) pass.ActionResult {
        var result = process.runWithCheckedOutput(self.cmd, a);
        defer result.deinit();
        if (result.ok()) {
            return .ok;
        } else {
            return .fail;
        }
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

test "Action_RunProcess" {
    const testing = @import("std").testing;
    const a = testing.allocator;
    {
        const run_echo = Action_RunProcess.init(&.{ "echo", "1" }).as_Action();
        try testing.expect(run_echo.run(a) == .ok);
    }
    {
        const run_incorrect = Action_RunProcess.init(&.{"random-incorrect-command"}).as_Action();
        try testing.expect(run_incorrect.run(a) == .fail);
    }
}

pub fn installAptPackages(comptime packages: []const []const u8) pass.Action {
    comptime {
        return Action_InstallAptPackages.init(packages).as_Action();
    }
}

test "installAptPackages" {
    _ = installAptPackages(&.{"123"});
}

pub const Action_InstallAptPackages = struct {
    const process = @import("process.zig");
    const Self = @This();
    packages: []const []const u8,

    pub fn init(packages: []const []const u8) Self {
        return .{ .packages = packages };
    }

    pub fn run(self: *const Self, a: Allocator) pass.ActionResult {
        var cmd = std.ArrayList([]const u8).init(a);
        defer cmd.deinit();
        for ([_][]const u8{ "apt", "install", "-y" }) |c| {
            cmd.append(c) catch return .fail;
        }
        for (self.packages) |p| {
            cmd.append(p) catch return .fail;
        }
        var result = process.runWithCheckedOutput(cmd.items, a);
        defer result.deinit();
        if (result.ok()) {
            return .ok;
        } else {
            return .fail;
        }
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

pub fn deleteFile(comptime path: []const u8) pass.Action {
    comptime {
        return Action_DeleteFile.init(path).as_Action();
    }
}

test "deleteFile" {
    _ = deleteFile("123");
}

pub const Action_DeleteFile = struct {
    const Self = @This();
    path: []const u8,

    pub fn init(path: []const u8) Self {
        return .{ .path = path };
    }

    pub fn run(self: *const Self, _: Allocator) pass.ActionResult {
        std.fs.deleteFileAbsolute(self.path) catch |e| {
            if (e == error.FileNotFound) {
                // file does not exist, no need to delete
                return .ok;
            }
            return .fail;
        };
        return .ok;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

pub fn writeFile(comptime path: []const u8, comptime data: []const u8) pass.Action {
    comptime {
        return Action_WriteFile.init(path, data).as_Action();
    }
}

test "writeFile" {
    _ = writeFile("123", "data");
}

pub const Action_WriteFile = struct {
    const Self = @This();
    path: []const u8,
    data: []const u8,

    pub fn init(path: []const u8, data: []const u8) Self {
        return .{ .path = path, .data = data };
    }

    pub fn run(self: *const Self, _: Allocator) pass.ActionResult {
        const file = std.fs.createFileAbsolute(self.path, .{ .truncate = true, .lock = .Exclusive }) catch return .fail;
        defer file.close();
        file.writeAll(self.data) catch return .fail;
        return .ok;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

test "Action_DeleteFile, Action_WriteFile" {
    const testing = @import("std").testing;
    const checks = @import("checks.zig");
    const a = testing.allocator;
    const test_file_path = "/tmp/testing_pass_write-file.txt";
    {
        const write_file = Action_WriteFile.init(test_file_path, "123").as_Action();
        try testing.expect(write_file.run(a) == .ok);
    }
    {
        const file_exists = checks.Check_IsFile.init(test_file_path).as_Check();
        try testing.expect(file_exists.yes(a));
    }
    {
        const delete_file = Action_DeleteFile.init(test_file_path).as_Action();
        try testing.expect(delete_file.run(a) == .ok);
    }
    {
        const file_exists = checks.Check_IsFile.init(test_file_path).as_Check();
        try testing.expect(!file_exists.yes(a));
    }
}

const fail = error.Fail;

fn userIdFromName(name: []const u8, a: Allocator) !u32 {
    const process = @import("process.zig");
    var result = process.runWithCheckedOutput(&.{ "id", "-u", name }, a);
    defer result.deinit();
    if (result.ok()) {
        return std.fmt.parseInt(u32, result.output.?.stdout.items, 10) catch return fail;
    }
    return fail;
}

test "userIdFromName" {
    const testing = @import("std").testing;
    const expect = testing.expect;
    const a = testing.allocator;
    const root_id = userIdFromName("root", a) catch unreachable;
    try expect(root_id == 0);
}

fn groupIdFromName(name: []const u8, a: Allocator) !u32 {
    const process = @import("process.zig");
    var result = process.runWithCheckedOutput(&.{ "getent", "group", name }, a);
    defer result.deinit();
    if (result.ok()) {
        var it = std.mem.split(u8, result.output.?.stdout.items, ":");
        _ = it.next() orelse return fail;
        _ = it.next() orelse return fail;
        const id_str = it.next() orelse return fail;
        return std.fmt.parseInt(u32, id_str, 10) catch return fail;
    }
    return fail;
}

test "groupIdFromName" {
    const testing = @import("std").testing;
    const expect = testing.expect;
    const a = testing.allocator;
    const root_id = groupIdFromName("root", a) catch unreachable;
    try expect(root_id == 0);
}

pub fn createDir(comptime path: []const u8, comptime access_mode: u64, comptime user_owner: []const u8, comptime group_owner: []const u8) pass.Action {
    comptime {
        return Action_CreateDir.init(path, access_mode, user_owner, group_owner).as_Action();
    }
}

test "createDir" {
    _ = createDir("123", 0o111, "root", "root");
}

pub const Action_CreateDir = struct {
    const Self = @This();
    path: []const u8,
    access_mode: u64,
    user_owner: []const u8,
    group_owner: []const u8,

    pub fn init(path: []const u8, access_mode: u64, user_owner: []const u8, group_owner: []const u8) Self {
        return .{ .path = path, .access_mode = access_mode, .user_owner = user_owner, .group_owner = group_owner };
    }

    pub fn run(self: *const Self, a: Allocator) pass.ActionResult {
        // todo: create recursive?
        std.fs.makeDirAbsolute(self.path) catch |e| {
            if (e != error.PathAlreadyExists) {
                return .fail;
            }
        };
        var dir = std.fs.openIterableDirAbsolute(self.path, .{}) catch return .fail;
        defer dir.close();
        dir.chmod(self.access_mode) catch return .fail;
        const user_id = userIdFromName(self.user_owner, a) catch return .fail;
        const group_id = groupIdFromName(self.group_owner, a) catch return .fail;
        dir.chown(user_id, group_id) catch return .fail;
        return .ok;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

// test "Action_CreateDir" {
//     const testing = @import("std").testing;
//     const expect = testing.expect;
//     const a = testing.allocator;
//     const path = "/tmp/testing_pass_create-dir";
//     {
//         const create_dir = Action_CreateDir.init(path, 0o666, "root", "root");
//         try expect(create_dir.run(a) == .ok);
//     }
// }

pub fn setFilePermissions(comptime path: []const u8, comptime access_mode: u64, comptime user_owner: []const u8, comptime group_owner: []const u8) pass.Action {
    comptime {
        return Action_SetFilePermissions.init(path, access_mode, user_owner, group_owner).as_Action();
    }
}

test "setFilePermissions" {
    _ = setFilePermissions("123", 0o111, "root", "root");
}

pub const Action_SetFilePermissions = struct {
    const Self = @This();
    path: []const u8,
    access_mode: u64,
    user_owner: []const u8,
    group_owner: []const u8,

    pub fn init(path: []const u8, access_mode: u64, user_owner: []const u8, group_owner: []const u8) Self {
        return .{ .path = path, .access_mode = access_mode, .user_owner = user_owner, .group_owner = group_owner };
    }

    pub fn run(self: *const Self, a: Allocator) pass.ActionResult {
        var file = std.fs.openFileAbsolute(self.path, .{}) catch return .fail;
        defer file.close();
        file.chmod(self.access_mode) catch return .fail;
        const user_id = userIdFromName(self.user_owner, a) catch return .fail;
        const group_id = groupIdFromName(self.group_owner, a) catch return .fail;
        file.chown(user_id, group_id) catch return .fail;
        return .ok;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

// test "Action_SetFilePermissions" {
//     const testing = @import("std").testing;
//     const expect = testing.expect;
//     const a = testing.allocator;
//     const path = "/tmp/testing_pass_set-file-permissions";
//     {
//         const write_file = Action_WriteFile.init(path, "abc");
//         try expect(write_file.run(a) == .ok);
//         const file_permissions = Action_SetFilePermissions.init(path, 0o664, "root", "root");
//         try expect(file_permissions.run(a) == .ok);
//     }
// }

pub fn replaceInFileOnce(comptime path: []const u8, comptime target: []const u8, comptime new_data: []const u8) pass.Action {
    comptime {
        return Action_ReplaceInFileOnce.init(path, target, new_data).as_Action();
    }
}

test "replaceInFileOnce" {
    _ = replaceInFileOnce("123", "aaa", "bbb");
}

pub const Action_ReplaceInFileOnce = struct {
    const Self = @This();
    path: []const u8,
    target: []const u8,
    new_data: []const u8,

    pub fn init(path: []const u8, target: []const u8, new_data: []const u8) Self {
        return .{ .path = path, .target = target, .new_data = new_data };
    }

    pub fn run(self: *const Self, a: Allocator) pass.ActionResult {
        const content = b: {
            var file = std.fs.openFileAbsolute(self.path, .{ .mode = .read_only }) catch return .fail;
            defer file.close();
            break :b file.reader().readAllAlloc(a, std.math.maxInt(u64)) catch return .fail;
        };
        defer a.free(content);
        const target_index = if (std.mem.indexOf(u8, content, self.target)) |i| i else return .fail;
        if (std.mem.indexOfPos(u8, content, target_index + self.target.len, self.target)) |_| {
            // found second entry of target_data, but expecting to have it only once in file
            return .fail;
        }
        const new_content = std.mem.join(a, &.{}, &.{
            content[0..target_index],
            self.new_data,
            content[(target_index + self.target.len)..],
        }) catch return .fail;
        defer a.free(new_content);
        {
            var file = std.fs.createFileAbsolute(self.path, .{ .truncate = true, .lock = .Exclusive }) catch return .fail;
            defer file.close();
            file.writeAll(new_content) catch return .fail;
        }
        return .ok;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

test "Action_ReplaceInFileOnce" {
    const testing = @import("std").testing;
    const expect = testing.expect;
    const a = testing.allocator;
    const checks = @import("checks.zig");
    const path = "/tmp/testing_pass_replace-in-file-once";
    {
        const write_file = Action_WriteFile.init(path, "1_abc_2").as_Action();
        try expect(write_file.run(a) == .ok);
        const replace_in_file = Action_ReplaceInFileOnce.init(path, "abc", "12345").as_Action();
        try expect(replace_in_file.run(a) == .ok);
        const check_content = checks.Check_FileContent.init(path, "1_12345_2").as_Check();
        try expect(check_content.yes(a));
    }
    {
        const write_file = Action_WriteFile.init(path, "1_abc_2_abc").as_Action();
        try expect(write_file.run(a) == .ok);
        const replace_in_file = Action_ReplaceInFileOnce.init(path, "abc", "12345").as_Action();
        try expect(replace_in_file.run(a) == .fail);
        const check_content = checks.Check_FileContent.init(path, "1_abc_2_abc").as_Check();
        try expect(check_content.yes(a));
    }
}

pub fn renameDir(comptime base_dir: []const u8, comptime rel_old_path: []const u8, comptime rel_new_path: []const u8) pass.Action {
    comptime {
        return Action_RenameDir.init(base_dir, rel_old_path, rel_new_path).as_Action();
    }
}

test "renameDir" {
    _ = renameDir("/tmp", "aaa", "bbb");
}

pub const Action_RenameDir = struct {
    const Self = @This();
    base_dir: []const u8,
    rel_old_path: []const u8,
    rel_new_path: []const u8,

    pub fn init(base_dir: []const u8, rel_old_path: []const u8, rel_new_path: []const u8) Self {
        std.debug.assert(std.fs.path.isAbsolute(base_dir));
        std.debug.assert(!std.fs.path.isAbsolute(rel_old_path));
        std.debug.assert(!std.fs.path.isAbsolute(rel_new_path));
        return .{ .base_dir = base_dir, .rel_old_path = rel_old_path, .rel_new_path = rel_new_path };
    }

    pub fn run(self: *const Self, _: Allocator) pass.ActionResult {
        var dir = std.fs.openDirAbsolute(self.base_dir, .{}) catch return .fail;
        defer dir.close();
        dir.rename(self.rel_old_path, self.rel_new_path) catch return .fail;
        return .ok;
    }

    pub fn as_Action(self: *const Self) pass.Action {
        return pass.Action.init(@typeName(Self), self, run);
    }
};

// test "Action_RenameDir" {
//     const testing = @import("std").testing;
//     const expect = testing.expect;
//     const a = testing.allocator;
//     const checks = @import("checks.zig");
//     {
//         _ = Action_CreateDir.init("/tmp/testing_pass_action_rename_dir", 0o777, "root", "root").run(a);
//         var rename = Action_RenameDir.init("/tmp/", "testing_pass_action_rename_dir", "testing_pass_action_rename_dir_new").as_Action();
//         try expect(rename.run(a) == .ok);
//         var check = checks.Check_IsDir.init("/tmp/testing_pass_action_rename_dir_new").as_Check();
//         try expect(check.yes(a));
//     }
// }
