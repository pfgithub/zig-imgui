const std = @import("std");
const builtin = @import("builtin");

const mach = @import("mach");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const use_freetype = b.option(bool, "use_freetype", "Use Freetype") orelse false;

    const mach_dep = b.lazyDependency("mach", .{
        .target = target,
        .optimize = optimize,
    }) orelse return;

    const module = b.addModule("zig-imgui", .{
        .root_source_file = b.path("src/imgui.zig"),
        .imports = &.{
            .{ .name = "mach", .module = mach_dep.module("mach") },
        },
    });

    const lib = b.addStaticLibrary(.{
        .name = "imgui",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();

    const imgui_dep = b.dependency("imgui", .{});

    var files = std.ArrayList(std.Build.LazyPath).init(b.allocator);
    defer files.deinit();

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    try files.appendSlice(&.{
        b.path("src/cimgui.cpp"),
        imgui_dep.path("imgui.cpp"),
        imgui_dep.path("imgui_widgets.cpp"),
        imgui_dep.path("imgui_tables.cpp"),
        imgui_dep.path("imgui_draw.cpp"),
        imgui_dep.path("imgui_demo.cpp"),
    });

    if (use_freetype) {
        try flags.append("-DIMGUI_ENABLE_FREETYPE");
        try files.append(imgui_dep.path("misc/freetype/imgui_freetype.cpp"));

        lib.linkLibrary((b.lazyDependency("freetype", .{
            .target = target,
            .optimize = optimize,
        }) orelse return).artifact("freetype"));
    }

    // oops!
    try flags.append("-fno-sanitize=undefined");
    try flags.append("-include" ++ "imconfig_override.h");

    lib.addIncludePath(b.path("src"));
    lib.addIncludePath(imgui_dep.path("."));

    for (files.items) |file| {
        lib.addCSourceFile(.{ .file = file, .flags = flags.items });
    }

    b.installArtifact(lib);

    // Example
    const build_options = b.addOptions();

    const app = try mach.CoreApp.init(b, mach_dep.builder, .{
        .name = "mach-imgui-example",
        .src = "examples/example_mach.zig",
        .target = target,
        .deps = &[_]std.Build.Module.Import{
            .{ .name = "imgui", .module = module },
            .{ .name = "build-options", .module = build_options.createModule() },
        },
        .optimize = optimize,
    });
    app.compile.linkLibrary(lib);

    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&app.run.step);

    // Generator
    const dear_bindings = b.lazyDependency("dear_bindings", .{}) orelse return;
    const generate_c = b.addSystemCommand(&.{"python3"});
    generate_c.addFileArg(dear_bindings.path("dear_bindings.py"));
    generate_c.addArg("-o");
    generate_c.addArg("src/cimgui");
    generate_c.addFileArg(imgui_dep.path("imgui.h"));

    // const generate_internal = b.addSystemCommand(&.{"python3"});
    // generate_internal.addFileArg(dear_bindings.path("dear_bindings.py"));
    // generate_internal.addArg("-o");
    // generate_internal.addArg("src/cimgui_internal");
    // generate_internal.addArg("--config-include");
    // generate_internal.addFileArg(imgui_dep.path("imgui.h"));
    // generate_internal.addFileArg(imgui_dep.path("imgui_internal.h"));

    const generator_exe = b.addExecutable(.{
        .name = "mach-imgui-generator",
        .root_source_file = b.path("src/generate.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(generator_exe);

    const generate_run = b.addRunArtifact(generator_exe);
    generate_run.addArg("src/cimgui.json");
    generate_run.addArg("src/imgui.zig");
    generate_run.step.dependOn(&generate_c.step);
    // generate_run.step.dependOn(&generate_internal.step);

    // const generate_run_2 = b.addRunArtifact(generator_exe);
    // generate_run_2.addArg("src/cimgui_internal.json");
    // generate_run_2.addArg("src/imgui_internal.zig");
    // generate_run_2.step.dependOn(&generate_c.step);
    // generate_run_2.step.dependOn(&generate_internal.step);

    const generate_step = b.step("generate", "Generate the bindings");
    generate_step.dependOn(&generate_run.step);
    // generate_step.dependOn(&generate_run_2.step);
}
