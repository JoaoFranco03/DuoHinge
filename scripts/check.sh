#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/duo-policy.XXXXXX")"
trap 'rm -f "$check_dir/policy-checks" "$check_dir/permission-checks"; rmdir "$check_dir"' EXIT

plutil -lint "$project_dir/DuoHinge.xcodeproj/project.pbxproj"
swiftc "$project_dir/DuoHinge/Core/HingePolicy.swift" \
    "$project_dir/DuoHinge/Core/HingeMotion.swift" \
    "$project_dir/DuoHinge/Core/CaptureRecoveryPolicy.swift" \
    "$project_dir/DuoHinge/Core/HingeViewpoint.swift" \
    "$project_dir/Tests/PolicyChecks.swift" -o "$check_dir/policy-checks"
"$check_dir/policy-checks"
swiftc "$project_dir/DuoHinge/Core/PermissionManager.swift" \
    "$project_dir/Tests/PermissionChecks.swift" -o "$check_dir/permission-checks"
"$check_dir/permission-checks"
