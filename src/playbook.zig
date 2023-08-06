const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const pass = @import("pass.zig");
const Check = pass.Check;
const Action = pass.Action;
const StoryFormatter = @import("story_formatter.zig").StoryFormatter;

pub const Instruction = struct {
    // status of action depending on check
    // b - before action
    // a - after action
    // t - all true or empty
    // f - all false
    // todo: m - mixed (some true, some false), e - empty
    // __________________________________
    // | action |_env___|_prep__|_conf__|
    // |________|_b_|_a_|_b_|_a_|_b_|_a_|
    // | fail   | f |   |   |   |   |   |
    // | fail   |   | f |   |   |   |   |
    // | fail   |   |   | f |   | f |   |
    // | fail   |   |   |   |   |   | f |
    // | ok     | t | t | t |   | f | t |
    // | ok     | t |   |   |   | t |   | action skipped in this case
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // for `prep` and `conf` all check should have same result, if mixed (some true, some false) means action failed
    env: []const Check = &.{},
    prep: []const Check = &.{},
    confirm: []const Check = &.{},
    action: Action,
};

// todo: silent option (do not print log)?
// todo: playbook description
pub const Playbook = struct {
    const Self = @This();
    // name of `Playbook` describing its purpose for user
    name: []const u8,
    // global environment checks, if any of this checks is false, all actions considered failed
    env_checks: []const Check,
    instructions: []const Instruction,

    pub fn init(name: []const u8, env_checks: []const Check, instructions: []const Instruction) Self {
        return .{ .name = name, .env_checks = env_checks, .instructions = instructions };
    }

    fn checkChecks(story: *StoryFormatter, checks: []const Check, ok_is_true: bool, a: Allocator) bool {
        var ok = true;
        for (checks, 0..) |envCheck, i| {
            var check_ok = envCheck.yes(a);
            if (!ok_is_true) {
                check_ok = !check_ok;
            }
            ok = check_ok and ok;
            story.checkListItem(check_ok, "{}.{s}", .{ i + 1, envCheck.name });
        }
        return ok;
    }

    fn checkResults(story: *StoryFormatter, checks: []const Check, a: Allocator) void {
        for (checks, 0..) |envCheck, i| {
            const check_ok = envCheck.yes(a);
            const result = if (check_ok) "true" else "flse";
            story.checkListItemResult(result, "{}.{s}", .{ i + 1, envCheck.name });
        }
    }

    fn allChecksYes(checks: []const Check, a: Allocator) bool {
        for (checks) |next_check| {
            if (!next_check.yes(a)) {
                return false;
            }
        }
        return true;
    }

    fn allChecksNo(checks: []const Check, a: Allocator) bool {
        for (checks) |next_check| {
            if (next_check.yes(a)) {
                return false;
            }
        }
        return true;
    }

    fn printRunResult(self: *const Self, ok: bool) void {
        const result_name = if (ok) "OK" else "FAIL";
        print("\n{s}\n\n{s}\n\n", .{ self.name, result_name });
    }

    // todo: add test for each if
    pub fn check(self: *const Self, a: Allocator) bool {
        print("Checking playbook: {s}\n", .{self.name});
        var playbook_ok: bool = true;
        defer self.printRunResult(playbook_ok);
        var failedActions = std.ArrayList(usize).init(a);
        defer failedActions.deinit();
        var story = StoryFormatter.init(a);
        {
            story.push("Playbook check");
            defer story.sectionResult(playbook_ok);
            if (self.env_checks.len > 0) {
                story.checkList("Environment");
                const env_ok = checkChecks(&story, self.env_checks, true, a);
                story.checkListResult(env_ok);
                playbook_ok = playbook_ok and env_ok;
            }
            {
                var actions_ok = true;
                story.push("Actions");
                defer story.sectionResult(actions_ok);
                for (self.instructions, 0..) |instruction, i| {
                    var action_ok = true;
                    const action_name = std.fmt.allocPrint(a, "{}.{s}", .{ i + 1, instruction.action.name }) catch unreachable;
                    defer a.free(action_name);
                    story.push(action_name);
                    defer story.sectionResult(action_ok);
                    if (instruction.env.len > 0) {
                        story.checkList("Environment");
                        const env_ok = checkChecks(&story, instruction.env, true, a);
                        story.checkListResult(env_ok);
                        action_ok = action_ok and env_ok;
                    }
                    if (instruction.confirm.len > 0) {
                        if (allChecksYes(instruction.confirm, a)) {
                            story.push("Confirmation");
                            story.checkListTitleWithNote("checking all confirmations is true");
                            // result not needed already known, all checks true
                            _ = checkChecks(&story, instruction.confirm, true, a);
                            story.checkListNote("action already applied, will be skipped");
                            story.checkListResult(true);
                        } else if (allChecksNo(instruction.confirm, a)) {
                            var confirmation_ok: bool = true;
                            story.push("Confirmation");
                            defer story.sectionResult(confirmation_ok);
                            var preparation_ok = true;
                            if (instruction.prep.len > 0) {
                                story.checkList("Preparation");
                                preparation_ok = checkChecks(&story, instruction.prep, true, a);
                                story.checkListResult(preparation_ok);
                            }
                            story.push("Confirmation");
                            story.checkListTitleWithNote("checking all confirmations is false");
                            // result not needed already known, all checks false
                            // todo: fn printChecksWithoutChecking(result: bool)
                            _ = checkChecks(&story, instruction.confirm, false, a);
                            story.checkListResult(true);
                            action_ok = preparation_ok and action_ok;
                        } else {
                            // some confirmation check true, some false
                            story.checkList("Confirmation");
                            checkResults(&story, instruction.confirm, a);
                            story.checkListNote("confirmation checks should be *all true* or *all false*");
                            story.checkListResult(false);
                            action_ok = false;
                        }
                    } else if (instruction.prep.len > 0) {
                        story.checkList("Preparation");
                        const preparation_ok = checkChecks(&story, instruction.prep, true, a);
                        story.checkListResult(preparation_ok);
                        action_ok = action_ok and preparation_ok;
                    }
                    if (!action_ok) {
                        failedActions.append(i) catch unreachable;
                    }
                    actions_ok = action_ok and actions_ok;
                }
                playbook_ok = playbook_ok and actions_ok;
            }
        }
        if (failedActions.items.len > 0) {
            print("\n", .{});
            print("Actions expected to fail:\n", .{});
            for (failedActions.items) |i| {
                print(" - {}.{s}\n", .{ i + 1, self.instructions[i].action.name });
            }
        }
        return playbook_ok;
    }

    // todo: add test for each if
    // todo: on fail print list of fully applied actions
    pub fn apply(self: *const Self, a: Allocator) bool {
        print("Applying playbook: {s}\n", .{self.name});
        var story = StoryFormatter.init(a);
        defer story.deinit();
        // using optional bool and defer for easier debugging of story sections, if variable was not assigned it is easy to spot which one and at what point
        var playbook_ok: ?bool = null;
        defer self.printRunResult(playbook_ok.?);
        story.push("Applying Playbook");
        defer story.sectionResult(playbook_ok.?);
        if (self.env_checks.len > 0) {
            story.checkList("Environment");
            const env_ok = checkChecks(&story, self.env_checks, true, a);
            story.checkListResult(env_ok);
            if (!env_ok) {
                playbook_ok = false;
                return false;
            }
        }
        var actions_ok: ?bool = null;
        story.push("Actions");
        defer story.sectionResult(actions_ok.?);
        for (self.instructions, 0..) |instruction, i| {
            const action_name = std.fmt.allocPrint(a, "{}.{s}", .{ i + 1, instruction.action.name }) catch unreachable;
            defer a.free(action_name);
            var action_ok: ?bool = null;
            story.push(action_name);
            defer story.sectionResult(action_ok.?);
            {
                // checks before action
                var pre_ok: ?bool = null;
                story.push("pre");
                defer story.sectionResult(pre_ok.?);
                if (instruction.env.len > 0) {
                    story.checkList("Environment");
                    const env_ok = checkChecks(&story, instruction.env, true, a);
                    story.checkListResult(env_ok);
                    if (!env_ok) {
                        pre_ok = false;
                        action_ok = false;
                        actions_ok = false;
                        playbook_ok = false;
                        return false;
                    }
                }
                if (instruction.confirm.len > 0) {
                    if (allChecksYes(instruction.confirm, a)) {
                        story.checkList("Confirmation");
                        _ = checkChecks(&story, instruction.confirm, true, a);
                        story.checkListNote("action already applied, skipping");
                        story.checkListResult(true);
                        pre_ok = true;
                        action_ok = true;
                        continue;
                    } else if (allChecksNo(instruction.confirm, a)) {
                        var confirmation_ok: ?bool = null;
                        story.push("Confirmation");
                        defer story.sectionResult(confirmation_ok.?);
                        var preparation_ok = true;
                        if (instruction.prep.len > 0) {
                            story.checkList("Preparation");
                            preparation_ok = checkChecks(&story, instruction.prep, true, a);
                            story.checkListResult(preparation_ok);
                        }
                        story.push("Confirmation");
                        story.checkListTitleWithNote("checking all confirmations is false");
                        // result not needed already known, all checks false
                        _ = checkChecks(&story, instruction.confirm, false, a);
                        story.checkListResult(true);
                        if (!preparation_ok) {
                            confirmation_ok = false;
                            pre_ok = false;
                            action_ok = false;
                            actions_ok = false;
                            playbook_ok = false;
                            return false;
                        }
                        confirmation_ok = true;
                    } else {
                        // some confirmation check true, some false
                        story.checkList("Confirmation");
                        checkResults(&story, instruction.confirm, a);
                        story.checkListNote("confirmation checks should be *all true* or *all false*");
                        story.checkListResult(false);
                        pre_ok = false;
                        action_ok = false;
                        actions_ok = false;
                        playbook_ok = false;
                        return false;
                    }
                } else if (instruction.prep.len > 0) {
                    story.checkList("Preparation");
                    const preparation_ok = checkChecks(&story, instruction.prep, true, a);
                    story.checkListResult(preparation_ok);
                    if (!preparation_ok) {
                        pre_ok = false;
                        action_ok = false;
                        actions_ok = false;
                        playbook_ok = false;
                        return false;
                    }
                }
                pre_ok = true;
            }
            {
                var apply_ok: ?bool = null;
                story.push("apply");
                defer story.processResult(apply_ok.?);
                story.sectionProcess();
                story.processMessage("applying");
                switch (instruction.action.run(a)) {
                    .ok => apply_ok = true,
                    .fail => {
                        apply_ok = false;
                        action_ok = false;
                        actions_ok = false;
                        playbook_ok = false;
                        return false;
                    },
                }
            }
            {
                // checks after action
                var post_ok: ?bool = null;
                story.push("post");
                defer story.sectionResult(post_ok.?);
                if (self.env_checks.len > 0) {
                    story.checkList("Playbook.Environment");
                    const env_ok = checkChecks(&story, self.env_checks, true, a);
                    story.checkListResult(env_ok);
                    if (!env_ok) {
                        post_ok = false;
                        action_ok = false;
                        actions_ok = false;
                        playbook_ok = false;
                        return false;
                    }
                }
                if (instruction.env.len > 0) {
                    story.checkList("Environment");
                    const env_ok = checkChecks(&story, instruction.env, true, a);
                    story.checkListResult(env_ok);
                    if (!env_ok) {
                        post_ok = false;
                        action_ok = false;
                        actions_ok = false;
                        playbook_ok = false;
                        return false;
                    }
                }
                if (instruction.confirm.len > 0) {
                    story.checkList("Confirmation");
                    var confirm_ok = checkChecks(&story, instruction.confirm, true, a);
                    story.checkListResult(confirm_ok);
                    if (!confirm_ok) {
                        post_ok = false;
                        action_ok = false;
                        actions_ok = false;
                        playbook_ok = false;
                        return false;
                    }
                }
                post_ok = true;
            }
            action_ok = true;
        }
        playbook_ok = true;
        actions_ok = true;
        return true;
    }
};
