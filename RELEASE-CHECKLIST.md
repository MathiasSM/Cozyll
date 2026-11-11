# Release checklist

1. **Bump the version** in `cozyll.cabal` (four-component PVP).

2. **Update `CHANGELOG.md`**: rename `[Unreleased]` to `[version]`, add its
   reference link, and add a fresh empty `[Unreleased]` section on top.

3. **Commit, push**: Use branch `release/vA.B.C.D` if possible.

4. **Open a release PR**: Review, merge.

5. **Merging triggers the release workflow**: This will tag `vX.Y.Z.W` if missing,
   and publish the release packages as drafts (GitHub, Hackage, ...).

6. **Verify the binary** (before publishing the draft):
   - the `release-binary` job's "Assert it is statically linked" step passed and printed
     `statically linked` / `not a dynamic executable`;
   - the `versioned` job's smoke test built and checked the example site with the kit binary;
   - `file kit/cozyll` says `statically linked` and `ldd kit/cozyll` says
     `not a dynamic executable`.

7. **Publish**: publish the GitHub release draft, and publish the Hackage
   candidate on hackage.haskell.org.
