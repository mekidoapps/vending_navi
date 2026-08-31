# Release evidence

Every release candidate must have one manifest created from
`RELEASE_MANIFEST_TEMPLATE.md`. A manifest is evidence, not approval: only an
independent GO decision permits Production promotion.

Rules:

- versionCode 17 is an audit baseline and is not releasable.
- Create the next candidate with a new versionCode after all P0/P1 work.
- Build only from a clean checkout of the recorded Git SHA.
- Do not replace unknown values with assumptions.
- Record hashes after the final source commit and before upload.
- Add Play-distributed device results and deployed Functions revisions before
  independent re-audit.

After the final source commit, print the immutable local evidence with:

```bash
tool/print_release_evidence.sh path/to/app-release.aab
```
