cask "i2pd-gui" do
  version "3.0.0"
  on_arm do
    sha256 "ad01d45b467a6cc31d00245ed1bdcf0b9c6236e1c89f23b422fe784a90b2ea0d"
    url "https://github.com/MetanoicArmor/gui-i2pd/releases/download/v#{version}/I2P-Daemon-GUI-#{version}.zip"
    app "I2P Daemon GUI.app"
  end

  on_intel do
    sha256 "8266178e0cab6e273f1b7f09ef0aa7e056983159a63b22aecf1e6b15f3b7ced0"
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
