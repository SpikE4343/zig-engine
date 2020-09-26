const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    //const mode = b.standardReleaseOptions();
    const exe = b.addExecutable("zngine", "src/engine.zig");

    // const libgame = b.addSharedLibrary("game", "src/game/game_cubes.zig", b.version(0, 1, 0));

    // exe.linkLibrary(libgame);

    //exe.setBuildMode(std.builtin.Mode.Debug);
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("c");

    //b.default_step.dependOn(&libgame.step);
    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);


    const run = b.step("run", "Run the engine");
    const run_cmd = exe.run();
    run.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(&exe.step);
}
