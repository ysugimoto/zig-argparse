const std = @import("std");

// Type indicates argument type convert to.
// We only supports premitive types like bool, integer, float and string.
const Type = enum(u8) {
    BOOLEAN,
    INT,
    FLOAT,
    STRING,
};

// ParseError is errors that will cause on parsing phase.
pub const Error = error{
    OptionUndefined,
    ValueNotProvided,
};

const Value = union {
    boolean: bool,
    int: i64,
    string: []const u8,
    float: f64,
};

// Internal struct of argument info.
const Argument = struct {
    argType: Type,
    value: Value,
};

// Main struct of ArgumentParser, allocate stack, parse, and retrieve them.
pub const ArgumentParser = struct {
    inner: std.process.ArgIterator,
    options: std.StringArrayHashMap(Argument),
    arguments: std.ArrayList([]const u8),

    pub fn option(self: *ArgumentParser, comptime T: type, name: []const u8, default: T) *ArgumentParser {
        switch (@Type(@typeInfo(T))) {
            i8, i16, i32, i64 => {
                self.options.put(name, Argument{
                    .argType = Type.INT,
                    .value = Value{ .int = @intCast(i64, default) },
                }) catch unreachable;
            },
            f16, f32, f64 => {
                self.options.put(name, Argument{
                    .argType = Type.FLOAT,
                    .value = Value{ .float = @floatCast(f64, default) },
                }) catch unreachable;
            },
            []const u8 => {
                self.options.put(name, Argument{
                    .argType = Type.STRING,
                    .value = Value{ .string = default },
                }) catch unreachable;
            },
            bool => {
                self.options.put(name, Argument{
                    .argType = Type.BOOLEAN,
                    .value = Value{ .boolean = default },
                }) catch unreachable;
            },
            else => unreachable, // option() accepts i8, i16, i32, f16, f32, f64, []const u8, bool types at comptime
        }

        return self;
    }

    pub fn at(self: *ArgumentParser, index: usize) ?[]const u8 {
        if (index < self.arguments.items.len) {
            return self.arguments.items[index];
        }
        return null;
    }

    pub fn get(self: *ArgumentParser, comptime T: type, name: []const u8) ?T {
        const opt = self.options.get(name) orelse {
            return null;
        };

        switch (@Type(@typeInfo(T))) {
            i8 => return @intCast(i8, opt.value.int),
            i16 => return @intCast(i16, opt.value.int),
            i32 => return @intCast(i32, opt.value.int),
            i64 => return @intCast(i64, opt.value.int),
            f16 => return @floatCast(f16, opt.value.float),
            f32 => return @floatCast(f32, opt.value.float),
            f64 => return @floatCast(f64, opt.value.float),
            []const u8 => return opt.value.string,
            bool => return opt.value.boolean,
            else => unreachable, // get() accepts i8, i16, i32, f16, f32, f64, []const u8, bool types at comptime
        }
    }

    pub fn parse(self: *ArgumentParser) anyerror!void {
        while (true) {
            var arg = self.inner.next() orelse {
                break;
            };

            if (arg[0] == '-') {
                // care long option like --foo
                const key = if (arg[1] == '-') arg[2..] else arg[1..];
                var o = self.options.get(key) orelse {
                    return Error.OptionUndefined;
                };

                switch (o.argType) {
                    .BOOLEAN => {
                        o.value.boolean = true;
                    },
                    .INT => {
                        var v = self.inner.next() orelse {
                            return Error.ValueNotProvided;
                        };
                        o.value.int = try std.fmt.parseInt(i64, v, 10);
                    },
                    .FLOAT => {
                        var v = self.inner.next() orelse {
                            return Error.ValueNotProvided;
                        };
                        o.value.float = try std.fmt.parseFloat(f64, v);
                    },
                    .STRING => {
                        var v = self.inner.next() orelse {
                            return Error.ValueNotProvided;
                        };
                        o.value.string = v[0..];
                    },
                }

                try self.options.put(key, o);
            } else {
                try self.arguments.append(arg[0..]);
            }
        }
    }

    pub fn init(allocator: std.mem.Allocator) ArgumentParser {
        return ArgumentParser{
            .inner = try std.process.argsWithAllocator(allocator),
            .options = std.StringArrayHashMap(Argument).init(allocator),
            .arguments = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ArgumentParser) void {
        self.inner.deinit();
        self.options.deinit();
        self.arguments.deinit();
    }
};

// Shorthand create ArgumentParser like std.process.argsWithAllocator.
pub fn argsWithAllocator(allocator: std.mem.Allocator) ArgumentParser {
    return ArgumentParser.init(allocator);
}
