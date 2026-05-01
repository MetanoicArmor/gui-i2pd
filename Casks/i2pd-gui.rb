cask "i2pd-gui" do
  version "2.60.0"
  on_arm do
    sha256 "90a93a6d90775be2ddad10f7b451187caf42a3d705ba1557e65e66ca71f1db71"
    url "https://github.com/MetanoicArmor/gui-i2pd/releases/download/v#{version}/I2P-Daemon-GUI-#{version}.zip"
    app "I2P Daemon GUI.app"
  end

  on_intel do
    sha256 "30474bff255113dbc6e6eb7581cfcc37fcea90d94049972cfff92ebaa60c0e1f"
    url "https://github.com/MetanoicArmor/gui-i2pd/releases/download/v#{version}/I2P-Daemon-GUI-Intel-#{version}.zip"
    app "I2P Daemon GUI-Intel.app", target: "I2P Daemon GUI.app"
  end

  name "I2P Daemon GUI"
  desc "Native macOS interface for the i2pd I2P network router"
  homepage "https://github.com/MetanoicArmor/gui-i2pd"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/I2P Daemon GUI.app"],
                   sudo: false
  end

  caveats <<~EOS
    This build is not Developer ID signed or notarized. macOS may report the app as
    "damaged" after install — that is Gatekeeper quarantine on files downloaded via Homebrew.
    The cask runs `xattr -dr com.apple.quarantine` automatically after install/upgrade,
    so the app should open without extra steps.

    If macOS still blocks it, run manually:
      xattr -dr com.apple.quarantine "/Applications/I2P Daemon GUI.app"
  EOS

  zap trash: [
    "~/Library/LaunchAgents/com.i2pd.daemon-gui.plist",
    "~/Library/Preferences/com.i2pd.daemon-gui.plist",
    "~/Library/Application Support/i2pd",
  ]
end
