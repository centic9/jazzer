# Copyright 2021 Code Intelligence GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

def java_fuzz_target_test(
        name,
        target_class = None,
        deps = [],
        hook_classes = [],
        native_libs = [],
        sanitizer = None,
        visibility = None,
        tags = [],
        fuzzer_args = [],
        srcs = [],
        **kwargs):
    target_name = name + "_target"
    deploy_manifest_lines = []
    if target_class:
        deploy_manifest_lines.append("Jazzer-Fuzz-Target-Class: %s" % target_class)
    if hook_classes:
        deploy_manifest_lines.append("Jazzer-Hook-Classes: %s" % ":".join(hook_classes))

    # Deps can only be specified on java_binary targets with sources, which
    # excludes e.g. Kotlin libraries wrapped into java_binary via runtime_deps.
    target_deps = deps + ["//agent:jazzer_api_compile_only"] if srcs else []
    native.java_binary(
        name = target_name,
        srcs = srcs,
        visibility = ["//visibility:private"],
        create_executable = False,
        deploy_manifest_lines = deploy_manifest_lines,
        deps = target_deps,
        **kwargs
    )

    additional_args = []

    if sanitizer == None:
        driver = "//driver:jazzer_driver"
    elif sanitizer == "address":
        driver = "//driver:jazzer_driver_asan"
    elif sanitizer == "undefined":
        driver = "//driver:jazzer_driver_ubsan"
    else:
        fail("Invalid sanitizer: " + sanitizer)

    native.java_test(
        name = name,
        runtime_deps = ["//bazel:fuzz_target_test_wrapper"],
        size = "enormous",
        timeout = "moderate",
        args = [
            "$(rootpath %s)" % driver,
            "$(rootpath :%s_deploy.jar)" % target_name,
        ] + additional_args + fuzzer_args,
        data = [
            ":%s_deploy.jar" % target_name,
            "//agent:jazzer_agent_deploy.jar",
            driver,
        ] + native_libs,
        main_class = "FuzzTargetTestWrapper",
        use_testrunner = False,
        tags = tags,
        visibility = visibility,
    )
