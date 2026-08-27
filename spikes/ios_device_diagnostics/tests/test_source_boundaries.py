# SPDX-License-Identifier: MPL-2.0
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[4]
SPIKE = ROOT / "community" / "spikes" / "ios_device_diagnostics"
APP = (SPIKE / "app" / "Stage2DiagnosticsApp.swift").read_text(encoding="utf-8")
BUILD = (SPIKE / "tool" / "build_unsigned_ipa.sh").read_text(encoding="utf-8")
PLIST = (SPIKE / "app" / "Info.plist").read_text(encoding="utf-8")


class IOSDeviceDiagnosticBoundaryTests(unittest.TestCase):
    def test_app_has_no_network_account_payment_or_secret_input_surface(self) -> None:
        forbidden = (
            "URLSession",
            "NWConnection",
            "http://",
            "https://",
            "Firebase",
            "StoreKit",
            "ASAuthorization",
            "UITextField",
            "SecureField",
        )
        for marker in forbidden:
            self.assertNotIn(marker, APP)

    def test_run_requires_explicit_user_action(self) -> None:
        self.assertIn("addTarget(self, action: #selector(runAllDiagnostics)", APP)
        self.assertNotIn("runAllDiagnostics()\n", APP.split("viewDidLoad", 1)[0])

    def test_exact_approved_argon2_grid_is_fixed_in_source(self) -> None:
        expected = (
            "(65_536, 2), (65_536, 3), (65_536, 4),\n"
            "        (98_304, 2), (98_304, 3), (98_304, 4),\n"
            "        (131_072, 2), (131_072, 3), (131_072, 4),"
        )
        self.assertIn(expected, APP)
        self.assertIn("for attachmentGiB in [1, 5]", APP)
        self.assertIn("collectReleaseEvidence", APP)

    def test_build_is_release_device_arm64_and_ios_15(self) -> None:
        for marker in (
            "-O \\",
            "-whole-module-optimization",
            "-target arm64-apple-ios15.0",
            "xcrun --sdk iphoneos",
            "MinimumOSVersion",
            "localhold-stage2-ios-device-$BUILD_REVISION.ipa",
            "shasum -a 256",
        ):
            self.assertIn(marker, BUILD)

    def test_package_excludes_profiles_extensions_and_advanced_entitlements(self) -> None:
        self.assertIn("embedded.mobileprovision", BUILD)
        self.assertIn("*.appex", BUILD)
        for marker in (
            "com.apple.security.application-groups",
            "com.apple.developer.associated-domains",
            "UIBackgroundModes",
        ):
            self.assertNotIn(marker, PLIST)

    def test_distributed_sources_have_mpl_marker(self) -> None:
        for path in SPIKE.rglob("*"):
            if path.suffix in {".swift", ".py", ".sh", ".plist"}:
                first_five = "\n".join(path.read_text(encoding="utf-8").splitlines()[:5])
                self.assertIn("SPDX-License-Identifier: MPL-2.0", first_five, str(path))


if __name__ == "__main__":
    unittest.main()
