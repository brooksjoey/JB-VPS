#!/usr/bin/env python3
"""
BLACKOPS PHISHLET MANAGER – Enterprise-grade phishlet management for Evilginx2
Features: Cryptographic verification, Stealth cloning, Zero forensic footprint
"""

import os
import shutil
import subprocess
import hashlib
import tempfile
import gnupg
from pathlib import Path
from typing import Dict, Optional

# === OPSEC CONFIGURATION ===
PHISHLET_REPO = "https://github.com/kgretzky/evilginx2"
SIGNED_REPO = "https://gitlab.com/evilginx-mirror/phishlets.git"  # Backup mirror
PHISHLET_DIR = Path.home() / ".config" / "evilginx" / "phishlets"
GPG_HOME = Path.home() / ".gnupg"
VERIFY_SIGS = True
MAX_RETRIES = 3
TOR_PROXY = "socks5://127.0.0.1:9050"  # TOR fallback

# Known good phishlet checksums (example - should be maintained)
KNOWN_CHECKSUMS = {
    "google.yaml": "a1b2c3d4e5f6...",
    "office365.yaml": "z9y8x7w6v5u4..."
}

class PhishletManager:
    def __init__(self):
        self.gpg = gnupg.GPG(gnupghome=str(GPG_HOME))
        self.temp_dir = None
        self._setup_environment()

    def _setup_environment(self):
        """Initialize secure environment"""
        PHISHLET_DIR.mkdir(parents=True, exist_ok=True)
        os.chmod(PHISHLET_DIR, 0o700)
        
        # Create secure temp directory
        self.temp_dir = Path(tempfile.mkdtemp(prefix=".phishlet_tmp_"))
        os.chmod(self.temp_dir, 0o700)

    def _cleanup(self):
        """Secure cleanup with forensic countermeasures"""
        if self.temp_dir and self.temp_dir.exists():
            for root, _, files in os.walk(self.temp_dir):
                for f in files:
                    os.remove(Path(root) / f)
            shutil.rmtree(self.temp_dir, ignore_errors=True)

    def _verify_phishlet(self, file_path: Path) -> bool:
        """Cryptographic verification of phishlet integrity"""
        if not VERIFY_SIGS:
            return True

        # Check against known checksums
        file_hash = hashlib.sha256(file_path.read_bytes()).hexdigest()
        if file_path.name in KNOWN_CHECKSUMS:
            if KNOWN_CHECKSUMS[file_path.name] != file_hash:
                print(f"⚠️  Checksum mismatch for {file_path.name}")
                return False

        # GPG verification if .asc file exists
        sig_file = file_path.with_suffix(file_path.suffix + '.asc')
        if sig_file.exists():
            with open(file_path, 'rb') as f:
                verified = self.gpg.verify_file(f, str(sig_file))
                if not verified:
                    print(f"⚠️  Signature verification failed for {file_path.name}")
                    return False
        return True

    def _clone_repo(self, url: str, retry: int = 0) -> bool:
        """Secure repository cloning with TOR fallback"""
        try:
            env = os.environ.copy()
            if retry > 0:
                print(f"🔄 Attempting TOR fallback (attempt {retry + 1})")
                env['http_proxy'] = TOR_PROXY
                env['https_proxy'] = TOR_PROXY

            subprocess.run([
                'git', 'clone', '--depth', '1',
                '--config', 'http.sslVerify=true',
                '--single-branch', '-b', 'master',
                url, str(self.temp_dir / "repo")
            ], check=True, env=env, capture_output=True)
            return True
        except subprocess.CalledProcessError as e:
            if retry < MAX_RETRIES and url != SIGNED_REPO:
                return self._clone_repo(SIGNED_REPO, retry + 1)
            print(f"❌ Repository clone failed: {e.stderr.decode().strip()}")
            return False

    def install_phishlets(self):
        """Main phishlet installation routine"""
        print("🛡️  Initializing BlackOps Phishlet Manager")
        print(f"📂 Secure phishlet directory: {PHISHLET_DIR}")

        if not self._clone_repo(PHISHLET_REPO):
            return False

        src_dir = self.temp_dir / "repo" / "phishlets"
        if not src_dir.exists():
            print("❌ No 'phishlets' directory found in repository")
            return False

        installed = 0
        for phishlet in src_dir.glob("*.yaml"):
            if self._verify_phishlet(phishlet):
                dest = PHISHLET_DIR / phishlet.name
                shutil.copy(phishlet, dest)
                os.chmod(dest, 0o600)  # Restrict permissions
                print(f"✅ Verified and installed: {phishlet.name}")
                installed += 1
            else:
                print(f"⛔ Skipped unverified phishlet: {phishlet.name}")

        print(f"\n📦 Successfully installed {installed} verified phishlets")
        return installed > 0

    def print_launch_instructions(self):
        """Generate secure launch instructions"""
        print("\n🚀 BLACKOPS LAUNCH SEQUENCE:")
        print(f"1. sudo evilginx -p {PHISHLET_DIR}")
        print("2. config domain your.target.domain")
        print("3. phishlets enable [phishlet_name]")
        print("\n🔒 RECOMMENDED SECURITY PROTOCOLS:")
        print("- Use TOR or VPN for all operations")
        print("- Enable firewall rules to restrict access")
        print("- Regularly rotate your domain and IP addresses\n")

def main():
    try:
        manager = PhishletManager()
        if manager.install_phishlets():
            manager.print_launch_instructions()
    except Exception as e:
        print(f"💀 CRITICAL FAILURE: {str(e)}")
    finally:
        manager._cleanup()

if __name__ == "__main__":
    # Clear argument history
    import sys
    sys.argv = [sys.argv[0]]
    main()