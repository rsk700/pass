const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;

pub const StoryFormatter = struct {
    const Self = @This();
    section_stack: std.ArrayList([]const u8),
    put_separator: bool = false,

    pub fn init(a: std.mem.Allocator) Self {
        return .{ .section_stack = std.ArrayList([]const u8).init(a) };
    }

    pub fn deinit(self: *Self) void {
        assert(self.section_stack.items.len == 0);
        self.section_stack.deinit();
    }

    pub fn push(self: *Self, name: []const u8) void {
        self.section_stack.append(name) catch unreachable;
    }

    fn contains_dot(data: []const u8) bool {
        for (data) |v| {
            if (v == '.') {
                return true;
            }
        }
        return false;
    }

    fn section(self: *Self) void {
        for (self.section_stack.items) |s, i| {
            const square_brackets = contains_dot(s);
            if (square_brackets) {
                print("[", .{});
            }
            print("{s}", .{s});
            if (square_brackets) {
                print("]", .{});
            }
            if (i < (self.section_stack.items.len - 1)) {
                print(".", .{});
            }
        }
    }

    fn separator() void {
        print("\n", .{});
    }

    pub fn checkList(self: *Self, title: []const u8) void {
        self.push(title);
        self.checkListTitle();
    }

    pub fn checkListTitle(self: *Self) void {
        self.checkListTitleWithNote(null);
    }

    pub fn checkListTitleWithNote(self: *Self, note: ?[]const u8) void {
        print(" _\n", .{});

        print("|", .{});
        self.section();
        print("\n", .{});

        print("|\n", .{});
        if (note) |n| {
            print("| *{s}*\n", .{n});
            print("|\n", .{});
        }
    }

    pub fn checkListItem(_: *Self, ok: bool, comptime title: []const u8, args: anytype) void {
        const result_name = if (ok) " ok " else "FAIL";
        print("|-[{s}] ", .{result_name});
        print(title, args);
        print("\n", .{});
    }

    pub fn checkListItemResult(_: *Self, result: []const u8, comptime title: []const u8, args: anytype) void {
        print("|-[{s}] ", .{result});
        print(title, args);
        print("\n", .{});
    }

    pub fn checkListNote(_: *Self, text: []const u8) void {
        print("|\n", .{});
        print("| *{s}*\n", .{text});
    }

    pub fn checkListResult(self: *Self, ok: bool) void {
        const result_name = if (ok) "ok" else "FAIL";
        print("|\n", .{});
        print("|> {s}\n", .{result_name});
        _ = self.section_stack.pop();
        self.put_separator = true;
    }

    pub fn sectionResult(self: *Self, ok: bool) void {
        const result_name = if (ok) "ok" else "FAIL";
        if (self.put_separator) {
            separator();
            self.put_separator = false;
        }
        self.section();
        print("|> {s}\n", .{result_name});
        _ = self.section_stack.pop();
    }

    pub fn sectionProcess(self: *Self) void {
        if (self.put_separator) {
            separator();
            self.put_separator = false;
        }
        self.section();
        print("|> ", .{});
    }

    pub fn processMessage(_: *Self, text: []const u8) void {
        print("...{s}", .{text});
    }

    pub fn processResult(self: *Self, ok: bool) void {
        const result_name = if (ok) "...done!" else "...FAIL!";
        print("{s}\n", .{result_name});
        _ = self.section_stack.pop();
    }
};
