const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// Check interface
pub const Check = struct {
    const Self = @This();
    name: []const u8,
    ptr: *const anyopaque,
    yesImpl: fn (ptr: *const anyopaque, a: Allocator) bool,

    pub fn init(name: []const u8, pointer: anytype, comptime yesFn: fn (@TypeOf(pointer), Allocator) bool) Self {
        const Ptr = @TypeOf(pointer);
        const ptr_info = @typeInfo(Ptr);
        assert(ptr_info == .Pointer);
        assert(ptr_info.Pointer.size == .One);
        const alignment = ptr_info.Pointer.alignment;
        const impl = struct {
            fn yes(ptr: *const anyopaque, a: Allocator) bool {
                const self: Ptr = if (@sizeOf(Ptr) == 0) undefined else @ptrCast(Ptr, @alignCast(alignment, ptr));
                return yesFn(self, a);
            }
        };

        return Self{ .name = name, .ptr = if (@sizeOf(Ptr) == 0) undefined else pointer, .yesImpl = impl.yes };
    }

    pub fn yes(self: *const Self, a: Allocator) bool {
        return self.yesImpl(self.ptr, a);
    }
};

pub const ActionResult = enum { ok, fail };

/// Action interface
pub const Action = struct {
    const Self = @This();
    name: []const u8,
    ptr: *const anyopaque,
    runImpl: fn (ptr: *const anyopaque, a: Allocator) ActionResult,

    pub fn init(name: []const u8, pointer: anytype, comptime runFn: fn (@TypeOf(pointer), Allocator) ActionResult) Self {
        const Ptr = @TypeOf(pointer);
        const ptr_info = @typeInfo(Ptr);
        assert(ptr_info == .Pointer);
        assert(ptr_info.Pointer.size == .One);
        const alignment = ptr_info.Pointer.alignment;
        const impl = struct {
            fn run(ptr: *const anyopaque, a: Allocator) ActionResult {
                const self: Ptr = if (@sizeOf(Ptr) == 0) undefined else @ptrCast(Ptr, @alignCast(alignment, ptr));
                return runFn(self, a);
            }
        };

        return Self{ .name = name, .ptr = if (@sizeOf(Ptr) == 0) undefined else pointer, .runImpl = impl.run };
    }

    pub fn run(self: *const Self, a: Allocator) ActionResult {
        return self.runImpl(self.ptr, a);
    }
};
