# Release checklist

1. **Bump the version** in `cozyll.cabal` (four-component PVP).

2. **Update `CHANGELOG.md`**: rename `[Unreleased]` to `[version]`, add its
   reference link, and add a fresh empty `[Unreleased]` section on top.

3. **Commit, push**: Use branch `release/vA.B.C.D` if possible.

4. **Open a release PR**: Review, merge.

5. **Merging triggers the release workflow**: This will tag `vX.Y.Z.W` if missing,
   and publish the release packages as drafts (GitHub, Hackage, ...).

6. **Verify**: publish the GitHub release draft, and publish the Hackage
   candidate on hackage.haskell.org.
