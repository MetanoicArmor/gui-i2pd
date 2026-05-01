cask "i2pd-gui" do
  version "2.60.0"
  on_arm do
    sha256 "5ffbe25d12fa4266bcaa8531dba15948185225f8042a2d811f09586fffe51f19"
    url "https://github.com/MetanoicArmor/gui-i2pd/releases/download/v#{version}/I2P-Daemon-GUI-#{version}.zip"
    app "I2P Daemon GUI.app"
  end

  on_intel do
    sha256 "8041e5bbb7408e0f0611741deea18b6fca1351d061944d47971c1f229f8d551b"
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

  zap trash: [
    "~/Library/LaunchAgents/com.i2pd.daemon-gui.plist",
    "~/Library/Preferences/com.i2pd.daemon-gui.plist",
    "~/Library/Application Support/i2pd",
  ]
end
