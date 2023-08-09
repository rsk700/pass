// build with:
// $ zig build

const std = @import("std");
const pass = @import("pass");
const checks = pass.checks;
const actions = pass.actions;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();
    const current_dir = std.process.getCwdAlloc(a) catch unreachable;
    defer a.free(current_dir);
    const file_path = std.fs.path.join(a, &.{ current_dir, "pass-example__hello_world.txt" }) catch unreachable;
    defer a.free(file_path);

    const book = pass.Playbook.init("Example creating file with \"Hello, world!\" text", &.{}, &[_]pass.Instruction{
        .{
            .confirm = &.{checks.Check_IsFile.init(file_path).as_Check()},
            .action = actions.Action_WriteFile.init(file_path, "Hello, world!").as_Action(),
        },
    });

    _ = book.apply(a);
}
