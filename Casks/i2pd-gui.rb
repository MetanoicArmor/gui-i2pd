cask "i2pd-gui" do
  version "2.60.0"
  on_arm do
    sha256 "9889405b641a3e37b05e13d84b770faad7bbc638bac7cadc14553cc86956024c"
    url "https://github.com/MetanoicArmor/gui-i2pd/releases/download/v#{version}/I2P-Daemon-GUI-#{version}.zip"
    app "I2P Daemon GUI.app"
  end

  on_intel do
    sha256 "14d7ad6d45c8a341b7522443ac76a32359f154b0bd320ad3a5858b016ae7158e"
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

  caveats <<~EOS
    This build is not Developer ID signed or notarized. macOS may report the app as
    "damaged" after install — that is Gatekeeper quarantine on files downloaded via Homebrew.
    Recent macOS versions may not show an "Open Anyway" option in System Settings for this case.

    Homebrew 4.7+ removed --no-quarantine (no replacement). After install or upgrade, run:
      xattr -dr com.apple.quarantine "/Applications/I2P Daemon GUI.app"
  EOS

  zap trash: [
    "~/Library/LaunchAgents/com.i2pd.daemon-gui.plist",
    "~/Library/Preferences/com.i2pd.daemon-gui.plist",
    "~/Library/Application Support/i2pd",
  ]
end
