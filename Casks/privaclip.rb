cask "privaclip" do
  version "1.0.0"
  sha256 "693ab4cc9b5cbf405d4a0f4c423ce5c42dd6a55978714d94e28eb6f339e0712a"

  url "https://github.com/shubhamghosh98/privaclip/releases/download/v#{version}/PrivaClip-macOS-arm64.zip"
  name "PrivaClip"
  desc "Privacy-first, native Apple Silicon clipboard manager with hardware AES-GCM encryption"
  homepage "https://github.com/shubhamghosh98/privaclip"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "PrivaClip.app"

  uninstall quit: "com.privaclip.app"

  zap trash: [
    "~/Library/Application Support/com.privaclip.app",
    "~/Library/Preferences/com.privaclip.app.plist",
  ]
end
