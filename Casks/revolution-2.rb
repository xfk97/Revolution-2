cask "revolution-2" do
  version "1.0.1"
  sha256 "6c82befd64d35cb0fbaa508925cd28e0c79a02371e1b7f8b0291188e34f67060"

  url "https://github.com/xfk97/Revolution-2/raw/main/Revolution-2.dmg"
  name "Revolution 2"
  desc "Local two-person chat application"
  homepage "https://github.com/xfk97/Revolution-2"

  depends_on macos: ">= :ventura"

  app "Revolution 2.app"

  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{appdir}/Revolution 2.app"]
  end

  zap trash: "~/.revolution"
end
