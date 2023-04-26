//! Zi version 0.13 or higher

const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Options
    const tests = b.option(bool, "tests", "Build tests [default: false]") orelse false;

    const librange = b.addStaticLibrary(.{
        .name = "range-v3",
        .target = target,
        .optimize = optimize,
    });
    librange.addIncludePath(b.path("include"));
    librange.installHeadersDirectory(b.path("include"), "", .{
        .exclude_extensions = &.{"modulemap"},
    });
    const empty_cpp = b.addWriteFile("empty.cpp", "// bypass for zig build");
    librange.addCSourceFiles(.{
        .root = empty_cpp.getDirectory(),
        .files = &.{"empty.cpp"},
    });
    b.installArtifact(librange);

    if (tests) {
        inline for (&.{
            "example/hello.cpp",
            "example/comprehensions.cpp",
            "example/count_if.cpp",
            "example/sort_unique.cpp",
            "example/for_each_assoc.cpp",
            "example/any_all_none_of.cpp",
            "example/view/transform.cpp",
            "example/view/filter.cpp",

            "perf/sort_patterns.cpp",
            "perf/counted_insertion_sort.cpp",

            "test/functional/bind_back.cpp",
            "test/bug474.cpp",
            "test/bug566.cpp",
            "test/bug1322.cpp",
            "test/bug1335.cpp",
            "test/bug1633.cpp",
            "test/bug1729.cpp",
            "test/multiple2.cpp",
            "test/constexpr_core.cpp",
            "test/config.cpp",

            "test/algorithm/binary_search.cpp",
            "test/algorithm/adjacent_remove_if.cpp",
            "test/algorithm/adjacent_find.cpp",
            "test/algorithm/generate_n.cpp",
            "test/algorithm/shuffle.cpp",
            "test/algorithm/swap_ranges.cpp",
            "test/algorithm/sort_n_with_buffer.cpp",
            "test/algorithm/unique.cpp",
            "test/range/conversion.cpp",
            "test/algorithm/make_heap.cpp",
            "test/algorithm/mismatch.cpp",
            "test/algorithm/sort_heap.cpp",
            "test/algorithm/stable_partition.cpp",
            "test/algorithm/next_permutation.cpp",
            "test/range/operations.cpp",
            "test/algorithm/set_union1.cpp",
            "test/algorithm/move_backward.cpp",
            "test/experimental/view/shared.cpp",
            "test/algorithm/set_union2.cpp",
            "test/algorithm/set_union3.cpp",
            "test/algorithm/set_union4.cpp",
            "test/algorithm/set_union5.cpp",
            "test/algorithm/set_union6.cpp",
            "test/algorithm/unstable_remove_if.cpp",
            "test/algorithm/nth_element.cpp",
            "test/algorithm/lexicographical_compare.cpp",
            // "test/experimental/utility/generator.cpp", // experimental::range
        }) |example| {
            buildTest(b, .{
                .lib = librange,
                .path = example,
            });
        }
    }
}

fn buildTest(b: *std.Build, info: BuildInfo) void {
    const test_exe = b.addExecutable(.{
        .name = info.filename(),
        .optimize = info.lib.root_module.optimize.?,
        .target = info.lib.root_module.resolved_target.?,
    });
    for (info.lib.root_module.include_dirs.items) |include_dir| {
        test_exe.root_module.include_dirs.append(b.allocator, include_dir) catch unreachable;
    }
    test_exe.addIncludePath(b.path("test"));
    test_exe.addCSourceFile(.{
        .file = b.path(info.path),
        .flags = cxxFlags,
    });
    if (test_exe.rootModuleTarget().abi == .msvc)
        test_exe.linkLibC()
    else
        test_exe.linkLibCpp();
    b.installArtifact(test_exe);

    const run_cmd = b.addRunArtifact(test_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(
        b.fmt("{s}", .{info.filename()}),
        b.fmt("Run the {s} test", .{info.filename()}),
    );
    run_step.dependOn(&run_cmd.step);
}

const cxxFlags = &.{
    // "-std=c++20",
    "-Wall",
    "-Wextra",
    "-Wpedantic",
};

const BuildInfo = struct {
    lib: *std.Build.Step.Compile,
    path: []const u8,

    fn filename(self: BuildInfo) []const u8 {
        var split = std.mem.splitSequence(u8, std.fs.path.basename(self.path), ".");
        return split.first();
    }
};
