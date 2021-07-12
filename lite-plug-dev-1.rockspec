-- vim: set shiftwidth=2 tabstop=2 expandtab :

package = "lite-plug"
version = "dev-1"
source = {
  url = "git+ssh://git@github.com/lukaswrz/lite-plug"
}
description = {
  summary = "A bare-bones plugin manager for Lite XL",
  homepage = "https://github.com/lukaswrz/lite-plug",
  license = "GPL-3"
}
dependencies = {
  "lua == 5.3",
  "luashell == 0.4-1",
  "argparse == 0.7.1-1",
  "rxi-json-lua == e1dbe93-0",
  "luafilesystem == 1.8.0-1"
}
build = {
  type = "builtin",
  modules = {
    ["lite-plug"] = "lite-plug.lua",
  },
  install = {
    bin = {
      ["lite-plug"] = "bin/lite-plug.lua"
    }
  }
}
