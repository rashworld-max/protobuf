# Protocol Buffers - Google's data interchange format
# Copyright 2024 Google Inc.  All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file or at
# https://developers.google.com/open-source/licenses/bsd
#
"""Tests for py_proto_library rule."""

load("@rules_python//python:proto.bzl", "py_proto_library")
load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_info.bzl", "PyInfo")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:util.bzl", "util")
load("//bazel:proto_library.bzl", "proto_library")

#TODO: test py proto library in protobuf/github/bazel as well

def py_proto_library_test_suite(name):
    """Test suite for py_proto_library."""
    test_suite(
        name = name,
        tests = [
            _test_collects_python_files_from_deps_when_srcs_is_empty,
            _test_python_binary_deps,
            _test_python_proto2_deps,
            _test_proto_toolchain_resolution_enabled,
        ],
    )

# Verifies py_proto_library on proto_library with no srcs generates outputs for deps.
def _test_collects_python_files_from_deps_when_srcs_is_empty(name):
    util.helper_target(
        proto_library,
        name = "b",
        srcs = ["b.proto"],
    )
    util.helper_target(
        proto_library,
        name = "a",
        deps = [":b"],
    )
    util.helper_target(
        py_proto_library,
        name = "a_py_pb",
        deps = [":a"],
    )
    analysis_test(
        name = name,
        target = ":a_py_pb",
        impl = _test_collects_python_files_from_deps_when_srcs_is_empty_impl,
    )

def _test_collects_python_files_from_deps_when_srcs_is_empty_impl(env, target):
    py_info = target[PyInfo]
    transitive_sources = [f.basename for f in py_info.transitive_sources.to_list()]

    env.expect.that_collection(transitive_sources).contains("b_pb2.py")

def _test_python_binary_deps(name):
    """Tests that py_proto_library includes outputs from proto_library.deps."""
    util.empty_file("bin.py")
    util.helper_target(
        proto_library,
        name = "bar",
        srcs = ["bar.proto"],
    )
    util.helper_target(
        proto_library,
        name = "foo",
        srcs = ["foo.proto"],
        deps = [":bar"],
    )
    util.helper_target(
        py_proto_library,
        name = "foo_py_pb",
        deps = [":foo"],
    )
    util.helper_target(
        py_binary,
        name = "bin",
        srcs = ["bin.py"],
        deps = [":foo_py_pb"],
    )
    analysis_test(
        name = name,
        target = ":bin",
        impl = _test_python_binary_deps_impl,
    )

def _test_python_binary_deps_impl(env, target):
    py_info = target[PyInfo]
    transitive_sources = [f.basename for f in py_info.transitive_sources.to_list()]

    env.expect.that_collection(transitive_sources).contains("foo_pb2.py")
    env.expect.that_collection(transitive_sources).contains("bar_pb2.py")
    env.expect.that_collection(transitive_sources).contains("bin.py")

def _test_python_proto2_deps(name):
    """Tests that py_proto_library depends on python proto2 library."""
    util.empty_file("bin_proto2_deps.py")
    util.helper_target(
        proto_library,
        name = "proto2_deps",
        srcs = ["file.proto"],
    )
    util.helper_target(
        py_proto_library,
        name = "py_proto2_deps_pb",
        deps = [":proto2_deps"],
    )
    util.helper_target(
        py_binary,
        name = "proto2_deps_bin",
        srcs = ["proto2_deps_bin.py"],
        deps = [":py_proto2_deps_pb"],
    )
    analysis_test(
        name = name,
        target = ":proto2_deps_bin",
        impl = _test_python_proto2_deps_impl,
    )

def _test_python_proto2_deps_impl(env, target):
    py_info = target[PyInfo]
    transitive_sources = [f.short_path for f in py_info.transitive_sources.to_list()]
    env.expect.that_collection(transitive_sources).contains("net/proto2/python/public/message.py")

def _test_proto_toolchain_resolution_enabled(name):
    """Tests that proto_library with proto_toolchain_resolution enabled works with py_proto_library."""
    util.helper_target(
        proto_library,
        name = "protolib",
        srcs = ["file.proto"],
    )
    util.helper_target(
        py_proto_library,
        name = "py_pb2",
        deps = [":protolib"],
    )
    util.helper_target(
        py_binary,
        name = "bin_proto_toolchain_resolution_enabled",
        srcs = ["bin_proto_toolchain_resolution_enabled.py"],
        deps = [":py_pb2"],
    )
    analysis_test(
        name = name,
        target = ":bin_proto_toolchain_resolution_enabled",
        impl = _test_proto_toolchain_resolution_enabled_impl,
        # flags = ["--incompatible_enable_proto_toolchain_resolution"],
    )

def _test_proto_toolchain_resolution_enabled_impl(env, target):
    runfiles_files = [f.short_path for f in target[DefaultInfo].default_files.files.to_list()]
    env.expect.that_collection(runfiles_files).not_contains("net/rpc/python/test_only_prefix_proto_python_api_2_stub.py")
    env.expect.that_collection(runfiles_files).contains("net/proto2/python/public/message.py")

    env.expect.that_collection(runfiles_files).contains("file_pb2.pyc")
