# Release checklist

## Source

- Run `bash scripts/check.sh` and Swift formatting checks.
- Build Release without signing to verify contributors do not need the maintainer's account.
- Run the offscreen Metal test and the manual checks in CONTRIBUTING.md.
- Verify minimum-OS behavior on real hardware. Compilation alone does not establish compatibility.
- Retain LICENSE, THIRD_PARTY_NOTICES.md, and Licenses/ in source distributions.
- Review every demo frame for personal data and confirm permission to distribute all artwork.
- Exclude build/, .DS_Store, Xcode user state, logs, credentials, and local exports.
  A .gitignore protects Git additions, not Finder ZIP archives.
- Verify README download links resolve to the intended published release.

## Binary

- Update marketing/build versions and describe behavior changes and known limitations.
- Archive with the maintainer's distribution identity; export for Developer ID distribution.
- Notarize and staple using Xcode's distribution workflow.
- Verify the exported app with `codesign --verify --deep --strict` and
  `spctl --assess --type execute --verbose=4`.
- Test a downloaded copy on another Mac, including first-run permissions,
  quitting while the overlay is active, sleep/wake, and display changes.
- Publish only the verified export, not an unsigned CI build or a local development app.

Repository settings must also be configured by the maintainer: enable private
vulnerability reporting, protect the release branch, and review who can publish.
The project retains its maintainer team ID for local signing; contributors must
select their own team or override DEVELOPMENT_TEAM. A team ID is not a signing key.
