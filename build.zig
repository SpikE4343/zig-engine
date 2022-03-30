const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const tracy = b.option(bool, "tracy", "Enable Tracy integration. Supply path to Tracy source") orelse false;
    const tracy_callstack = b.option(bool, "tracy-callstack", "Include callstack information with Tracy data. Does nothing if -Dtracy is not provided") orelse false;
    const tracy_allocation = b.option(bool, "tracy-allocation", "Include allocation information with Tracy data. Does nothing if -Dtracy is not provided") orelse false;
    const debug_build = b.option(bool, "debug", "Debug build") orelse true;

    //const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("zngine", "src/engine.zig");

    // const libgame = b.addSharedLibrary("game", "src/game/game_cubes.zig", b.version(0, 1, 0));

    // exe.linkLibrary(libgame);
    //exe.setBuildMode(mode);

    //exe.setBuildMode(std.builtin.Mode.ReleaseSafe);

    if (debug_build) {
        exe.setBuildMode(std.builtin.Mode.Debug);
    } else {
        exe.setBuildMode(std.builtin.Mode.ReleaseFast);
    }

    const exe_options = b.addOptions();
    exe.addOptions("build_options", exe_options);
    exe_options.addOption(bool, "enable_tracy", tracy);
    exe_options.addOption(bool, "enable_tracy_callstack", tracy_callstack);
    exe_options.addOption(bool, "enable_tracy_allocation", tracy_allocation);
    exe_options.addOption(bool, "debug mode", debug_build);

    if (tracy) {
        const tracyPath = "../../tracy";

        const client_cpp = std.fs.path.join(b.allocator, &[_][]const u8{ tracyPath, "TracyClient.cpp" }) catch unreachable;

        exe.addIncludeDir(tracyPath);
        exe.addCSourceFile(client_cpp, &[_][]const u8{ "-DTRACY_ENABLE=1", "-DTRACY_NO_SYSTEM_TRACING=1", "-fno-sanitize=undefined" });
        exe.linkSystemLibrary("c++");

        if (builtin.os.tag == .windows) {
            exe.linkSystemLibrary("dbghelp");
            exe.linkSystemLibrary("ws2_32");
        }
    }

    if (builtin.os.tag == .windows) {
        var sdl_path = b.fmt("{s}/external/win/SDL2", .{b.build_root});
        // std.debug.print("{s}", .{sdl_path});
        exe.addLibPath(b.fmt("{s}/lib/x64", .{sdl_path}));
        exe.addIncludeDir(b.fmt("{s}/include", .{sdl_path}));
        exe.addIncludeDir("C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.17763.0\\shared\\evntprov.h");
        b.installBinFile(b.fmt("{s}/lib/x64/SDL2.dll", .{sdl_path}), "SDL2.dll");
        exe.linkSystemLibrary("sdl2");
    } else {
        exe.linkSystemLibrary("SDL2");
    }

    //exe.linkLibC();

    exe.linkSystemLibrary("c");
    //

    //b.default_step.dependOn(&libgame.step);
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);

    const run = b.step("run", "Run the engine");
    const run_cmd = exe.run();
    run.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(&exe.step);
}
