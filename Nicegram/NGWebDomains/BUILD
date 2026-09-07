load("@bazel_skylib//rules:write_file.bzl", "write_file")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(":web_domains.bzl", "NICEGRAM_ALL_DOMAINS", "NICEGRAM_PRIMARY_DOMAIN")

write_file(
    name = "NicegramWebDomainsGenerated",
    out = "Generated/NicegramWebDomains+Generated.swift",
    content = [
        "// Generated from Nicegram/NGWebDomains/web_domains.bzl. Do not edit.",
        "",
        "let nicegramAllDomains: [String] = [{}]".format(
            ", ".join(['"{}"'.format(domain) for domain in NICEGRAM_ALL_DOMAINS]),
        ),
        'let nicegramPrimaryDomain = "{}"'.format(NICEGRAM_PRIMARY_DOMAIN),
    ],
)

swift_library(
    name = "NGWebDomains",
    module_name = "NGWebDomains",
    srcs = glob(["Sources/**/*.swift"]) + [":NicegramWebDomainsGenerated"],
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
