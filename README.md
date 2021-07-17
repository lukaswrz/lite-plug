<!-- vim: set shiftwidth=4 tabstop=4 expandtab : -->
# lite-plug

lite-plug is a *very* bare-bones CLI plugin manager for
[Lite XL](https://github.com/lite-xl/lite-xl).

Feature requests welcome.

## Dependencies

* [argparse](https://luarocks.org/modules/mpeterv/argparse)
* [luashell](https://luarocks.org/modules/mna/luashell)
* [rxi-json-lua](https://luarocks.org/modules/djfdyuruiry/rxi-json-lua)
* [LuaFileSystem](https://luarocks.org/modules/hisham/luafilesystem)

It currently requires Lua 5.3.

Additionally, `git` and `curl` have to be installed and available in `$PATH`.

## Installation

Clone and enter the repository, then:

```console
$ # alternatively: luarocks --local --lua-version 5.3 make lite-plug-dev-1.rockspec
$ sudo luarocks --lua-version 5.3 make lite-plug-dev-1.rockspec
$ mkdir -p -- "${XDG_CONFIG_HOME:-$HOME/.config}/lite-plug/plugins"
$ cp -- index.json "${XDG_CONFIG_HOME:-$HOME/.config}/lite-plug"
```

## Configuration

If all you need is theme16 and autoinsert.lua, this index file would suffice:

```json
{
    "autoinsert.lua":{
        "urls":[
            "https://raw.githubusercontent.com/lite-xl/lite-plugins/master/plugins/autoinsert.lua"
        ],
        "kind":"file"
    },
    "theme16":{
        "urls":[
            "https://github.com/monolifed/theme16"
        ],
        "kind":"git"
    }
}
```

This file path has to be `$XDG_CONFIG_HOME/lite-plug/index.json` or
`$HOME/.config/lite-plug/index.json`.

A [JSON file](index.json) containing all data for the plugins listed on
[lite-plugins](https://github.com/lite-xl/lite-plugins) is included.

## Example usage

```console
$ lite-plug install theme16 autosave.lua
Installing "theme16" via "git"... Done.
Activating "theme16"... Done.
Installing "autosave.lua" via "file"... Done.
Activating "autosave.lua"... Done.
$ lite-plug deactivate autosave.lua
Deactivating "autosave.lua"... Done.
$ lite-plug update
Updating "theme16" via "git"... Done.
Updating "autosave.lua" via "file"... Done.
$ lite-plug remove theme16
Deactivating "theme16"... Done.
Removing "theme16"... Done.
$ lite-plug activate autosave.lua
Activating "autosave.lua"... Done.
$ lite-plug search --installed true --activated true autosave
"autosave.lua"
$ lite-plug install --reinstall autosave.lua
Removing "autosave.lua"... Done.
Installing "autosave.lua" via "file"... Done.
```
