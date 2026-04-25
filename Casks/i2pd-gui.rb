cask "i2pd-gui" do
  version "2.60.0"
  sha256 "0fd0a75101d5315c767db7eb8d9eab64dce89f8670cf70dee98868aaf58e1bcd"

  url "https://github.com/MetanoicArmor/gui-i2pd/releases/download/v#{version}/I2P-Daemon-GUI-#{version}.zip"
  name "I2P Daemon GUI"
  desc "Native macOS interface for the i2pd I2P network router"
  homepage "https://github.com/MetanoicArmor/gui-i2pd"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "I2P Daemon GUI.app"

  zap trash: [
    "~/Library/LaunchAgents/com.i2pd.daemon-gui.plist",
    "~/Library/Preferences/com.i2pd.daemon-gui.plist",
    "~/Library/Application Support/i2pd",
  ]
end
