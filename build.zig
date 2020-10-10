const std = @import("std");
const os = std.os;
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    //const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("zngine", "src/engine.zig");

    // const libgame = b.addSharedLibrary("game", "src/game/game_cubes.zig", b.version(0, 1, 0));

    // exe.linkLibrary(libgame);
    //exe.setBuildMode(mode);
    //exe.setBuildMode(std.builtin.Mode.Debug);

    if(std.builtin.os.tag == .windows) {
        exe.addIncludeDir("external/SDL2-2.0.12/include");
        exe.linkSystemLibrary("external/SDL2-2.0.12/lib/x64/SDL2");
    } else {    
        exe.linkSystemLibrary("SDL2");
    }
    exe.linkSystemLibrary("c");

    //b.default_step.dependOn(&libgame.step);
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);


    const run = b.step("run", "Run the engine");
    const run_cmd = exe.run();
    run.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(&exe.step);
}
