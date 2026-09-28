---
name: dependency-audit
description: Dependency and supply-chain security auditing — vulnerability scanning of third-party packages, lockfile integrity, transitive dependency risk, license compliance, and supply-chain attack patterns (typosquatting, compromised maintainers). Use whenever reviewing project dependencies, package.json/requirements.txt/pom.xml/go.mod, discussing supply-chain security, or the user mentions dependency vulnerabilities or SBOM.
---

# Dependency Risk and Supply-Chain Auditing

Most production vulnerabilities today are inherited from dependencies, not written in first-party code. Treat the dependency tree as part of the attack surface, not a trusted given.

## Automated vulnerability scanning — required, not optional

- Run a dependency vulnerability scanner in CI on every build, not just periodically: `npm audit`/`yarn audit`, `pip-audit`, `OWASP Dependency-Check`, `Snyk`, `Trivy` (also scans container images), or the ecosystem-native tool (`go list -m all` + `govulncheck`, `cargo audit`, `bundler-audit`).
- Fail the build (or at minimum, require explicit sign-off) on new critical/high-severity vulnerabilities introduced by a dependency bump — don't just generate a report nobody reads.

```bash
npm audit --audit-level=high
pip-audit -r requirements.txt
govulncheck ./...
cargo audit
```

## Lockfile integrity

- Commit the lockfile (`package-lock.json`/`yarn.lock`/`pnpm-lock.yaml`, `poetry.lock`/`Pipfile.lock`, `Gemfile.lock`, `go.sum`, `Cargo.lock`) — without it, a build can silently resolve to a different (potentially compromised) transitive version than the one that was reviewed.
- Verify checksums/integrity hashes on install (most package managers do this automatically when a lockfile is present — confirm it isn't disabled) so a tampered package registry response is detected rather than silently installed.
- Pin exact versions for anything security-sensitive (auth libraries, crypto libraries) rather than a broad range, even where the lockfile would otherwise resolve consistently for the team — this makes an unexpected version bump visible in the diff.

## Transitive dependency risk

- A vulnerability doesn't have to be in a direct dependency to matter — scanners must traverse the full transitive tree; a direct dependency's outdated sub-dependency is just as exploitable.
- Periodically review the full dependency tree size and depth — an unusually deep or wide tree for the functionality gained is itself a risk signal (larger attack surface, more maintainers who must each remain trustworthy).
- Use `npm ls <package>`/`pip show`/`mvn dependency:tree`/`go mod graph` to trace exactly which direct dependency pulled in a flagged transitive package, so the fix (usually an upgrade or an override/resolution pin) targets the right place.

## Supply-chain attack patterns to watch for

- **Typosquatting**: a malicious package with a name one character off from a popular package (`reqeusts` vs `requests`) — verify package names carefully, especially when adding a new dependency from a suggestion rather than official documentation.
- **Compromised maintainer accounts / malicious version bumps**: a previously-trustworthy package publishes a version with injected malicious code (install-time scripts that exfiltrate environment variables/credentials are a common vector). Mitigate with: disabling install-time lifecycle scripts by default where the package manager supports it (`npm install --ignore-scripts` as a default posture, enabling per-package only where genuinely needed), pinning to a specific reviewed version rather than auto-upgrading on every release, and a short delay/quarantine period before adopting a brand-new major version release of a critical dependency.
- **Dependency confusion**: an internal package name that also exists on the public registry — an attacker publishes a malicious public package with the same name, and a misconfigured build resolves to the public one instead of the internal one. Mitigate by scoping internal packages under a registered namespace/scope and configuring the package manager to only ever resolve that scope from the private registry.

## License compliance

- Scan dependency licenses (`license-checker`, `pip-licenses`, `FOSSA`, `license_finder`) to catch a copyleft license (GPL/AGPL) pulled into a codebase whose distribution model is incompatible with it, before it ships.
- Track license obligations per dependency in the same place vulnerability data is tracked (an SBOM), so a license question can be answered without re-auditing the whole tree.

## Software Bill of Materials (SBOM)

- Generate an SBOM (CycloneDX or SPDX format) as part of the build for any software shipped to customers or used in a regulated context — it is both an audit artifact and the fastest way to answer "are we affected by CVE-XXXX" the next time a major vulnerability is disclosed.

```bash
# Example: generating a CycloneDX SBOM for a Node project
npx @cyclonedx/cyclonedx-npm --output-file sbom.json
```

## Remediation workflow

1. Identify the flagged package and the direct dependency that introduced it.
2. Check if a patched version exists that satisfies the existing version range — prefer the smallest version bump that resolves the vulnerability over a major-version jump done reflexively.
3. If no patch exists, evaluate: is the vulnerable code path actually reachable in how the dependency is used? (Not an excuse to ignore it indefinitely, but informs urgency.) Consider a temporary override/resolution pin to a patched transitive version, or replacing the dependency.
4. Re-run the full test suite after any version bump — a security patch can include breaking changes.

## Quick scan checklist

- [ ] A dependency vulnerability scanner runs in CI on every build, with a defined severity gate
- [ ] Lockfiles committed and checksum verification enabled
- [ ] Transitive tree included in scans, not just direct dependencies
- [ ] Install-time lifecycle scripts disabled by default, enabled only where explicitly needed
- [ ] Internal package names scoped/namespaced to prevent dependency confusion
- [ ] License scan run and any copyleft conflicts flagged before release
- [ ] An SBOM generated and kept current for shipped software
