# zig-argparse

Simple CLI argument parser for Zig.

## Installation

Check out this project or use some package manager.

## Usage / Example

```zig
const std = @import("std");
const argparge = @import("argparse.zig");

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var args = argparse.argsWithAllocator(allocator);
    defer args.deinit();

    // Define options and parse from std.os.argv
    try args
        .option(i64, "i", 10)          // define -i [int] option, default is 10
        .option([]const u8, "s", "")   // define -s [string] option, default is empty
        .option(bool, "b", false)      // define -b option, default is false
        .option([]const u8, "foo", "") // define --foo option, default is empty
        .option(f64, "f", 0.0)         // define -f option, default is 0.0
        .parse();                      // execute parse

    // Retrieve parsed result, all get() result is optional so you need to check.

    // boolean
    if (args.get(bool, "b")) |value| {
      std.debug.print("-b option value: {b}\n", .{value});
    }
    // integer
    if (args.get(i32, "i")) |value| {
      std.debug.print("-i option value: {d}\n", .{value});
    }
    // float
    if (args.get(f32, "f")) |value| {
      std.debug.print("-f option value: {any}\n", .{value});
    }
    // string
    if (args.get([]const u8, "s")) |value| {
      std.debug.print("-s option value: {s}\n", .{value});
    }
    // subcommand
    if (args.at(1)) |value| {
      std.debug.print("subcommand: {s}\n", .{value});
    }
}
```

## License

MIT License

## Author

Yoshiaki Sugimoto
