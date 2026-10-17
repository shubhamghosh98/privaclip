cask "privaclip" do
  version "1.0.0"
  sha256 "89418b2734ac6a996911b11c08fe83b4c0bc03b227e760686e702daf0ac48ccc"

  # Replace <GITHUB_USERNAME> with your actual GitHub username or organization
  url "https://github.com/<GITHUB_USERNAME>/privaclip/releases/download/v#{version}/PrivaClip-macOS-arm64.zip"
  name "PrivaClip"
  desc "Privacy-first, native Apple Silicon clipboard manager with hardware AES-GCM encryption"
  homepage "https://github.com/<GITHUB_USERNAME>/privaclip"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false
  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "PrivaClip.app"

  uninstall quit: "com.privaclip.app"

  zap trash: [
    "~/Library/Application Support/com.privaclip.app",
    "~/Library/Preferences/com.privaclip.app.plist",
  ]
end
