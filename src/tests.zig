test "all tests" {
    const testing = @import("std").testing;
    testing.refAllDeclsRecursive(@import("main.zig"));
    testing.refAllDeclsRecursive(@import("actions.zig"));
    testing.refAllDeclsRecursive(@import("checks.zig"));
    testing.refAllDeclsRecursive(@import("process.zig"));
}
