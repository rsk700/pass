**status**: experimental, unstable

# Bt

Bt - is a simple templating engine.

# Usage example

Only string values is supported.

```
const std = @import("std");
const bt = @import("bt");

const text = try bt.gen(std.testing.allocator, "aaa {--value1--} {--value2--} {--value1--}", .{.value1="111", .value2="222"});
defer std.testing.allocator.free(text);
// text is: "aaa 111 222 111"
```

comptime variant:
```
const bt = @import("bt");

const text = bt.genComptime("aaa {--value1--} {--value2--} {--value1--}", .{.value1="111", .value2="222"});
// text is: "aaa 111 222 111"
```

escaping `{--`:
```
const bt = @import("bt");

const text = bt.genComptime("{--\"{--\"--}", .{});
// text is: "{--"
```

Bt uses a lot of backward branches at compile-time you may need to increase it with `@setEvalBranchQuota`.