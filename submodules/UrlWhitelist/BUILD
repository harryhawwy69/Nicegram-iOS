load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "UrlWhitelist",
    module_name = "UrlWhitelist",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    # Nicegram Domain
    deps = [
        "//Nicegram/NGWebDomains:NGWebDomains",
    ],
    visibility = [
        "//visibility:public",
    ],
)
