# Release checklist

1. **Bump the version** in `cozyll.cabal` (four-component PVP).

2. **Update `CHANGELOG.md`**: rename `[Unreleased]` to `[version]`, add its
   reference link, and add a fresh empty `[Unreleased]` section on top.

3. **Commit, push**: Use branch `release/vA.B.C.D` if possible.

4. **Open a release PR**: Review, merge.

5. **Merging triggers the release workflow**: it tags `vX.Y.Z.W` if missing, builds
   the kit, runs the smoke and format/HTML/JSON-LD/XML checks, and **publishes** the
   GitHub release. The publish step is last, so a failure blocks publication.

6. **Verify the published release**:
   - both assets (`cozyll-kit.tar.gz` and `.sha256`) are attached to the release;
   - the `release-binary` job log shows `max glibc symbol: GLIBC_2.36` and no
     `GLIBC_2.37+` symbols;
   - the `versioned` job's "Check the binary on the glibc baseline and on Debian 13"
     step printed a version from both `debian:12` and `debian:13`;
   - download the kit, verify the checksum, and run `./cozyll --version` on Debian 13;
   - `file kit/cozyll` / `ldd kit/cozyll` show only the expected runtime libraries.

7. **Hackage**: publish the candidate on hackage.haskell.org (the CI job uploads a
   candidate only when `HACKAGE_ENABLED` is `true`).
