#!/bin/bash
# Not called anywhere in this repo, CI, or fastlane -- that is expected, not
# dead code. The developer runs this by hand (typically
# `./nicegram-match.sh development`) to install/refresh the local development
# signing certificate that Xcode device builds need. Before the fix described
# in the `nicegram_match` lane (ci/fastlane/Fastfile), a local release build
# silently destroyed that certificate and this was the by-hand recovery step;
# the lane now installs `development` into the login keychain so it is no
# longer wiped by a release build, but this script is still the supported way
# to (re)run that installation on demand. Do not delete this in a future
# dead-script audit.
#
# Keep the #!/bin/bash line and this cd -- see ci/verify-build.sh's header for
# why the shebang matters, and note that `. ./_env.sh` below resolves relative
# to the caller's cwd, so without the cd this only works from ci/.
cd "$(dirname "$0")" || exit 1

. ./_env.sh
fastlane nicegram_match type:$1
