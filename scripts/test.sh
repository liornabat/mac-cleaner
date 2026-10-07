#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
flags=()
developer_dir="$(xcode-select -p)"
framework_dir="$developer_dir/Library/Developer/Frameworks"
if [ -d "$framework_dir/Testing.framework" ]; then
  flags=(-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xswiftc -F -Xswiftc "$framework_dir" -Xlinker -rpath -Xlinker "$framework_dir")
fi
if [ "${#flags[@]}" -gt 0 ]; then
  swift test --disable-xctest "${flags[@]}"
else
  swift test --disable-xctest
fi
