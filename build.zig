const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    //const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("zngine", "src/engine.zig");

    // const libgame = b.addSharedLibrary("game", "src/game/game_cubes.zig", b.version(0, 1, 0));

    
    // exe.linkLibrary(libgame);
    //exe.setBuildMode(mode);
    //exe.setBuildMode(std.builtin.Mode.ReleaseSafe);
    exe.setBuildMode(std.builtin.Mode.Debug);


    // const tracyPath = "../../tracy";

    // const client_cpp = std.fs.path.join(
    //     b.allocator,
    //     &[_][]const u8{ tracyPath, "TracyClient.cpp" }
    // ) catch unreachable;

    // exe.addIncludeDir(tracyPath);
    // exe.addCSourceFile(client_cpp, &[_][]const u8{"-DTRACY_ENABLE=1", "-DTRACY_NO_SYSTEM_TRACING=1", "-fno-sanitize=undefined"});
    


    if(builtin.os.tag == .windows) {
        var sdl_path = b.fmt("{s}/external/win/SDL2", .{b.build_root});
        // std.debug.print("{s}", .{sdl_path});
        exe.addLibPath(b.fmt("{s}/lib/x64", .{sdl_path}));
        exe.addIncludeDir(b.fmt("{s}/include", .{sdl_path}));
        exe.addIncludeDir("C:\\Program Files (x86)\\Windows Kits\\10\\Include\\10.0.17763.0\\shared\\evntprov.h");
        b.installBinFile( b.fmt("{s}/lib/x64/SDL2.dll", .{sdl_path}), "SDL2.dll");
        exe.linkSystemLibrary("sdl2");

        
    } else {    
        exe.linkSystemLibrary("SDL2");
    }
    
    //exe.linkLibC();
    // exe.linkSystemLibrary("c++");
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
