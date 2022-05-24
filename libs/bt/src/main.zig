const std = @import("std");
const assert = std.debug.assert;
const TypeInfo = std.builtin.TypeInfo;

const Section = struct {
    // section start index
    a: usize,
    // section end index (exclusive)
    b: usize,
    data: []const u8,
};

const Token = union(enum) {
    Text: Section,
    // "{--"
    BracketLeft: Section,
    // "--}"
    BracketRight: Section,
    // ' " '
    Quote: Section,
    End: Section,

    const Self = @This();

    pub fn isEnd(self: *const Self) bool {
        return switch (self.*) {
            .End => true,
            else => false,
        };
    }

    pub fn data(self: *const Self) []const u8 {
        const section = switch (self.*) {
            .Text => |t| t,
            .BracketLeft => |t| t,
            .BracketRight => |t| t,
            .Quote => |t| t,
            .End => |t| t,
        };
        return section.data;
    }
};

const Tokenizer = struct {
    const Self = @This();
    data: []const u8,
    cursor: usize = 0,

    pub fn init(data: []const u8) Self {
        return .{ .data = data };
    }

    fn isSpecial(symbol: u8) bool {
        return symbol == '{' or symbol == '-' or symbol == '"';
    }

    pub fn current(self: *Self) Token {
        // todo: refactor?
        const cursor = self.cursor;
        const token = self.consume();
        self.cursor = cursor;
        return token;
    }

    pub fn peekNext(self: *Self) Token {
        const cursor = self.cursor;
        _ = self.consume();
        const token = self.consume();
        self.cursor = cursor;
        return token;
    }

    pub fn consume(self: *Self) Token {
        if (self.cursor == self.data.len) {
            return Token{ .End = .{ .a = self.data.len, .b = self.data.len, .data = &.{} } };
        }
        if ((self.cursor + 3) <= self.data.len) {
            const data_section = self.data[self.cursor .. self.cursor + 3];
            if (std.mem.eql(u8, data_section, "{--")) {
                defer self.cursor += 3;
                return Token{ .BracketLeft = .{ .a = self.cursor, .b = self.cursor + 3, .data = data_section } };
            } else if (std.mem.eql(u8, data_section, "--}")) {
                defer self.cursor += 3;
                return Token{ .BracketRight = .{ .a = self.cursor, .b = self.cursor + 3, .data = data_section } };
            }
        }
        if (self.data[self.cursor] == '"') {
            defer self.cursor += 1;
            return Token{ .Quote = .{ .a = self.cursor, .b = self.cursor + 1, .data = self.data[self.cursor .. self.cursor + 1] } };
        }
        var n: usize = 1;
        while (true) {
            if ((self.cursor + n) == self.data.len) {
                break;
            } else if (isSpecial(self.data[self.cursor + n])) {
                break;
            }
            n += 1;
        }
        defer self.cursor += n;
        return Token{ .Text = .{ .a = self.cursor, .b = self.cursor + n, .data = self.data[self.cursor .. self.cursor + n] } };
    }
};

fn sectionEql(a: Section, b: Section) bool {
    return a.a == b.a and a.b == b.b and std.mem.eql(u8, a.data, b.data);
}

fn tokenEql(a: Token, b: Token) bool {
    return switch (a) {
        .Text => |sa| switch (b) {
            .Text => |sb| sectionEql(sa, sb),
            else => false,
        },
        .BracketLeft => |sa| switch (b) {
            .BracketLeft => |sb| sectionEql(sa, sb),
            else => false,
        },
        .BracketRight => |sa| switch (b) {
            .BracketRight => |sb| sectionEql(sa, sb),
            else => false,
        },
        .Quote => |sa| switch (b) {
            .Quote => |sb| sectionEql(sa, sb),
            else => false,
        },
        .End => |sa| switch (b) {
            .End => |sb| sectionEql(sa, sb),
            else => false,
        },
    };
}

test "Tokenizer" {
    const expect = std.testing.expect;
    {
        {
            const text = "aaa";
            var t = Tokenizer.init(text);
            try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 0, .b = 3, .data = "aaa" } }));
            try expect(tokenEql(t.consume(), Token{ .End = .{ .a = 3, .b = 3, .data = "" } }));
        }
        {
            comptime {
                const text = "aaa";
                var t = Tokenizer.init(text);
                try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 0, .b = 3, .data = "aaa" } }));
                try expect(tokenEql(t.consume(), Token{ .End = .{ .a = 3, .b = 3, .data = "" } }));
            }
        }
        {
            var t = Tokenizer.init("{--value1--}");
            try expect(tokenEql(t.consume(), Token{ .BracketLeft = .{ .a = 0, .b = 3, .data = "{--" } }));
            try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 3, .b = 9, .data = "value1" } }));
            try expect(tokenEql(t.consume(), Token{ .BracketRight = .{ .a = 9, .b = 12, .data = "--}" } }));
        }
        {
            const text = "aa {- bbb {-- kkk --} ddd \" ddd";
            var t = Tokenizer.init(text);
            try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 0, .b = 3, .data = "aa " } }));
            try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 3, .b = 4, .data = "{" } }));
            try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 4, .b = 10, .data = "- bbb " } }));
            try expect(tokenEql(t.consume(), Token{ .BracketLeft = .{ .a = 10, .b = 13, .data = "{--" } }));
            try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 13, .b = 18, .data = " kkk " } }));
            try expect(tokenEql(t.consume(), Token{ .BracketRight = .{ .a = 18, .b = 21, .data = "--}" } }));
            try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 21, .b = 26, .data = " ddd " } }));
            try expect(tokenEql(t.consume(), Token{ .Quote = .{ .a = 26, .b = 27, .data = "\"" } }));
            try expect(tokenEql(t.consume(), Token{ .Text = .{ .a = 27, .b = 31, .data = " ddd" } }));
            try expect(tokenEql(t.consume(), Token{ .End = .{ .a = 31, .b = 31, .data = "" } }));
        }
    }
}

const Element = union(enum) {
    Text: []const u8,
    Name: []const u8,
};

fn parse(comptime data: []const u8) []const Element {
    comptime {
        var tok = Tokenizer.init(data);
        var elements: []const Element = &.{};
        while (!tok.current().isEnd()) {
            switch (tok.current()) {
                .Text => |t| {
                    elements = elements ++ &[_]Element{.{ .Text = t.data }};
                    // consume current token
                    _ = tok.consume();
                },
                .BracketLeft => elements = elements ++ &[_]Element{parseParameter(&tok)},
                .BracketRight => |t| {
                    elements = elements ++ &[_]Element{.{ .Text = t.data }};
                    _ = tok.consume();
                },
                .Quote => |t| {
                    elements = elements ++ &[_]Element{.{ .Text = t.data }};
                    _ = tok.consume();
                },
                else => unreachable,
            }
        }
        return elements;
    }
}

// todo: on error report line and position
fn parseParameter(comptime tok: *Tokenizer) Element {
    comptime {
        switch (tok.current()) {
            .BracketLeft => switch (tok.peekNext()) {
                .Text => return parseName(tok),
                .Quote => return parseLiteral(tok),
                else => @compileError("expecting `text` or `\"`"),
            },
            else => unreachable,
        }
    }
}

fn parseName(comptime tok: *Tokenizer) Element {
    comptime {
        switch (tok.consume()) {
            .BracketLeft => {},
            else => @compileError("expecting `{--`"),
        }
        const name: []const u8 = switch (tok.consume()) {
            .Text => |t| std.mem.trim(u8, t.data, " "),
            else => @compileError("expecting `text`"),
        };
        switch (tok.consume()) {
            .BracketRight => {},
            else => @compileError("expecting `--}`"),
        }
        return Element{ .Name = name };
    }
}

fn parseLiteral(comptime tok: *Tokenizer) Element {
    comptime {
        switch (tok.consume()) {
            .BracketLeft => {},
            else => @compileError("expecting `{--`"),
        }
        switch (tok.consume()) {
            .Quote => {},
            else => @compileError("expecting `\"`"),
        }
        const literal: []const u8 = switch (tok.consume()) {
            .BracketLeft => |t| t.data,
            else => @compileError("expecting literal `{--`"),
        };
        switch (tok.consume()) {
            .Quote => {},
            else => @compileError("expecting `\"`"),
        }
        switch (tok.consume()) {
            .BracketRight => {},
            else => @compileError("expecting `--}`"),
        }
        return Element{ .Text = literal };
    }
}

test "parse" {
    const expect = std.testing.expect;
    {
        const elements = parse("aaa {--value1--}");
        try expect(elements.len == 2);
    }
}

/// caller owns returned data
pub fn gen(a: std.mem.Allocator, comptime template: []const u8, args: anytype) ![]const u8 {
    // todo: compile error on unused fields from args
    const elements = comptime parse(template);
    var data = std.ArrayList(u8).init(a);
    defer data.deinit();
    inline for (elements) |e| {
        switch (e) {
            .Text => |text| for (text) |d| {
                try data.append(d);
            },
            .Name => |name| for (@field(args, name)) |d| {
                try data.append(d);
            },
        }
    }
    return try a.dupe(u8, data.items);
}

test "gen" {
    const expect = std.testing.expect;
    const a = std.testing.allocator;
    {
        const data = gen(a, "", .{}) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, ""));
    }
    {
        const data = gen(a, "a", .{}) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "a"));
    }
    {
        const data = gen(a, "aaa", .{}) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "aaa"));
    }
    {
        const data = gen(a, "aaa", .{}) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "aaa"));
    }
    {
        const data = gen(a, "{ }", .{}) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "{ }"));
    }
    {
        const data = gen(a, "--}", .{}) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "--}"));
    }
    {
        const data = gen(a, "aaa {--value1--}", .{ .value1 = "123" }) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "aaa 123"));
    }
    {
        const data = gen(a, "aaa {--value1--} {-- value1 --}", .{ .value1 = "123" }) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "aaa 123 123"));
    }
    {
        const data = gen(a, "{--\"{--\"--}", .{}) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "{--"));
    }
    {
        const data = gen(a, "aaa {--v1--} {--v2--} {--v1--}", .{ .v1 = "111", .v2 = "222" }) catch unreachable;
        defer a.free(data);
        try expect(std.mem.eql(u8, data, "aaa 111 222 111"));
    }
}

pub fn genComptime(comptime template: []const u8, comptime args: anytype) []const u8 {
    comptime {
        const elements = parse(template);
        var data: []const u8 = &.{};
        for (elements) |e| {
            switch (e) {
                .Text => |t| data = data ++ t,
                .Name => |n| data = data ++ @field(args, n),
            }
        }
        return data;
    }
}

test "genComptime" {
    const expect = std.testing.expect;
    {
        const data = genComptime("aaa", .{});
        try expect(std.mem.eql(u8, data, "aaa"));
    }
    {
        const data = genComptime("aaa {--value1--}", .{ .value1 = "123" });
        try expect(std.mem.eql(u8, data, "aaa 123"));
    }
    {
        const data = genComptime("aaa {--value1--} {-- value1 --}", .{ .value1 = "123" });
        try expect(std.mem.eql(u8, data, "aaa 123 123"));
    }
    {
        const data = genComptime("{--\"{--\"--}", .{});
        try expect(std.mem.eql(u8, data, "{--"));
    }
    {
        const data = genComptime("aaa {--v1--} {--v2--} {--v1--}", .{ .v1 = "111", .v2 = "222" });
        try expect(std.mem.eql(u8, data, "aaa 111 222 111"));
    }
}
