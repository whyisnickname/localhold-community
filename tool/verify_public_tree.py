# SPDX-License-Identifier: MPL-2.0
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

REQUIRED_PATHS = {
    ".github/workflows/community-ci.yml",
    "CONTRIBUTING.md",
    "LICENSE",
    "README.md",
    "SECURITY.md",
    "TRADEMARK_POLICY.md",
    "TRADEMARK_POLICY_PLAIN.md",
    "apps/mobile_free/pubspec.lock",
    "apps/mobile_free/pubspec.yaml",
    "docs/legal/OPEN_CORE_LICENSING.md",
    "docs/security/SECURITY_CONTACT.md",
}
FORBIDDEN_ROOTS = {"infra", "services"}
FORBIDDEN_PATHS = {
    "apps/mobile",
    "packages/vault_commercial_policy",
}
FORBIDDEN_TOKENS = {
    "-".join(("LicenseRef", "Localhold", "Proprietary")),  # noqa: FLY002
    "".join(("LOCALHOLD_", "BACKEND_URL")),  # noqa: FLY002
    "".join(("LOCALHOLD_", "SECRET_KEY")),  # noqa: FLY002
    "".join(("PUBLIC_OWNER_", "NAME_REQUIRED")),  # noqa: FLY002
    "".join(("security@", "example.invalid")),  # noqa: FLY002
}
FORBIDDEN_SUFFIXES = {".jks", ".keystore", ".p12", ".pfx", ".pem"}
HEX_REVISION = re.compile(r"^[0-9a-f]{40}$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify(root: Path) -> None:
    root = root.resolve()
    manifest_path = root / "PUBLIC_SOURCE_MANIFEST.json"
    if not manifest_path.is_file():
        raise ValueError("PUBLIC_SOURCE_MANIFEST.json is missing")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    revision = manifest.get("source_revision", "")
    if not isinstance(revision, str) or HEX_REVISION.fullmatch(revision) is None:
        raise ValueError("Manifest source_revision must be a full Git SHA")
    expected = manifest.get("files")
    if not isinstance(expected, dict):
        raise TypeError("Manifest files must be an object")

    actual: set[str] = set()
    for path in root.rglob("*"):
        relative = path.relative_to(root).as_posix()
        if relative == ".git" or relative.startswith(".git/"):
            continue
        if path.is_symlink():
            raise ValueError(f"Symlink is prohibited: {relative}")
        if path.is_dir():
            continue
        if relative == "PUBLIC_SOURCE_MANIFEST.json":
            continue
        actual.add(relative)
        if path.suffix.lower() in FORBIDDEN_SUFFIXES:
            raise ValueError(f"Secret-like file is prohibited: {relative}")
        data = path.read_bytes()
        for token in FORBIDDEN_TOKENS:
            if token.encode("utf-8") in data:
                raise ValueError(f"Forbidden token in {relative}: {token}")

    missing = REQUIRED_PATHS - actual
    if missing:
        raise ValueError(f"Required public paths are missing: {sorted(missing)}")
    unexpected = actual - set(expected)
    missing_manifest_entries = set(expected) - actual
    if unexpected or missing_manifest_entries:
        raise ValueError(
            "Manifest/tree mismatch: "
            f"unexpected={sorted(unexpected)}, missing={sorted(missing_manifest_entries)}"
        )

    if any(path == ".git" or path.startswith(".git/") for path in expected):
        raise ValueError("Git metadata must not be included in the source manifest")

    for root_name in FORBIDDEN_ROOTS:
        if any(
            path == root_name or path.startswith(f"{root_name}/") for path in actual
        ):
            raise ValueError(f"Forbidden root is present: {root_name}")
    for prefix in FORBIDDEN_PATHS:
        if any(path == prefix or path.startswith(f"{prefix}/") for path in actual):
            raise ValueError(f"Forbidden private path is present: {prefix}")
    for relative, expected_hash in expected.items():
        if sha256(root / relative) != expected_hash:
            raise ValueError(f"Hash mismatch: {relative}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path, nargs="?", default=Path.cwd())
    args = parser.parse_args()
    verify(args.root)
    print("public mirror verification passed")


if __name__ == "__main__":
    main()
