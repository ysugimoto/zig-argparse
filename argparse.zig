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
pub const ParseError = error{
    FlagUndefined,
    ValueNotProvided,
};

// Internal struct of argument info.
// TODO: we should use union Type
const Argument = struct {
    argType: Type,
    boolValue: ?bool,
    intValue: ?i64,
    stringValue: ?[]const u8,
    floatValue: ?f64,
};

// Main struct of ArgumentParser, allocate stack, parse, and retrieve them.
pub const ArgumentParser = struct {
    inner: std.process.ArgIterator,
    options: std.StringArrayHashMap(Argument),
    arguments: std.ArrayList([]const u8),

    pub fn option(self: *ArgumentParser, comptime T: type, name: []const u8, default: ?T) *ArgumentParser {
        var arg = Argument{
            .argType = Type.BOOLEAN,
            .boolValue = null,
            .intValue = null,
            .stringValue = null,
            .floatValue = null,
        };
        switch (@Type(@typeInfo(T))) {
            i8, i16, i32, i64 => {
                arg.argType = Type.INT;
                arg.intValue = if (default) |value| @intCast(i64, value) else null;
            },
            f16, f32, f64 => {
                arg.argType = Type.FLOAT;
                arg.floatValue = if (default) |value| @floatCast(f64, value) else null;
            },
            []const u8 => {
                arg.argType = Type.STRING;
                arg.stringValue = if (default) |value| value else null;
            },
            bool => {
                arg.argType = Type.BOOLEAN;
                arg.boolValue = if (default) |value| value else null;
            },
            else => unreachable, // option() accepts i8, i16, i32, f16, f32, f64, []const u8, bool types at comptime
        }
        self.options.put(name, arg) catch unreachable;

        return self;
    }

    pub fn at(self: *ArgumentParser, index: usize) ?[]const u8 {
        if (index < self.arguments.items.len) {
            return self.arguments.items[index];
        }
        return null;
    }

    pub fn get(self: *ArgumentParser, comptime T: type, name: []const u8) ?T {
        const value = self.options.get(name) orelse {
            return null;
        };

        switch (@Type(@typeInfo(T))) {
            i8 => return @intCast(i8, value.intValue.?),
            i16 => return @intCast(i16, value.intValue.?),
            i32 => return @intCast(i32, value.intValue.?),
            i64 => return @intCast(i64, value.intValue.?),
            f16 => return @floatCast(f16, value.floatValue.?),
            f32 => return @floatCast(f32, value.floatValue.?),
            f64 => return @floatCast(f64, value.floatValue.?),
            []const u8 => return value.stringValue,
            bool => return value.boolValue,
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
                    return ParseError.FlagUndefined;
                };

                switch (o.argType) {
                    .BOOLEAN => {
                        o.boolValue = true;
                    },
                    .INT => {
                        var v = self.inner.next() orelse {
                            return ParseError.ValueNotProvided;
                        };
                        o.intValue = try std.fmt.parseInt(i64, v, 10);
                    },
                    .FLOAT => {
                        var v = self.inner.next() orelse {
                            return ParseError.ValueNotProvided;
                        };
                        o.floatValue = try std.fmt.parseFloat(f64, v);
                    },
                    .STRING => {
                        var v = self.inner.next() orelse {
                            return ParseError.ValueNotProvided;
                        };
                        o.stringValue = v[0..];
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
