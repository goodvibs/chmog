const std = @import("std");

fn writeBinaryData(outputPath: []const u8, data: anytype) !void {
    if (std.fs.path.dirname(outputPath)) |dir_path| {
        std.fs.cwd().makePath(dir_path) catch |err| switch (err) {
            error.PathAlreadyExists => {}, // Directory exists, that's fine
            else => return err,
        };
    }

    var file = try std.fs.cwd().createFile(outputPath, .{});
    defer file.close();

    const bytes = std.mem.asBytes(&data);
    try file.writeAll(bytes);

    std.debug.print("Wrote {} bytes to {s}\n", .{ bytes.len, outputPath });
}
