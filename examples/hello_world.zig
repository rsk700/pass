// run with:
// $ zig run examples/hello_world.zig --pkg-begin pass src/pass.zig

const std = @import("std");
const pass = @import("pass");
const checks = pass.checks;
const actions = pass.actions;

pub fn main() void {
    const a = std.testing.allocator;
    const current_dir = std.process.getCwdAlloc(a) catch unreachable;
    defer a.free(current_dir);
    const file_path = std.fs.path.join(a, &.{ current_dir, "pass-example__hello_world.txt" }) catch unreachable;
    defer a.free(file_path);

    const book = pass.Playbook.init(&.{}, &[_]pass.Instruction{
        .{
            .confirm = &.{checks.Check_IsFile.init(file_path).as_Check()},
            .action = actions.Action_WriteFile.init(file_path, "Hello, world!").as_Action(),
        },
    });

    _ = book.apply(a);
}
