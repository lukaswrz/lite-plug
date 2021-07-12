#!/usr/bin/env lua5.3
-- vim: set shiftwidth=2 tabstop=2 expandtab :

-- imports

local argparse = require "argparse"
local sh = require "shell"
local json = require "rxi-json-lua"
local fs = require "lfs"

-- constants

local CONFIG_DIR = (function()
  local xdg_config_home = os.getenv("XDG_CONFIG_HOME")
  if xdg_config_home ~= nil and xdg_config_home ~= "" then
    return xdg_config_home
  end
  local home = os.getenv("HOME")
  if home == nil then
    os.exit(1)
  end
  return home .. "/.config"
end)()

local LITE_DIR = CONFIG_DIR .. "/lite-xl"
local LITE_PLUGIN_DIR = LITE_DIR .. "/plugins"
local SELF_DIR = CONFIG_DIR .. "/lite-plug"
local SELF_PLUGIN_DIR = SELF_DIR .. "/plugins"
local SELF_INDEX_PATH = SELF_DIR .. "/index.json"

-- utilities

local function put(str, file)
  local f = file or io.stdout
  f:write(tostring(str))
end

local function consume(path)
  local f = io.open(path, "r")
  if f == nil then
    return nil
  end
  local rv = f:read("*a")
  f:close()
  return rv
end

local function report(str, status)
  put(str, io.stderr)
  os.exit(status or 1)
end

local function quote(str)
  return string.format("%q", tostring(str))
end

local function verbose(description, fn)
  put(description .. "...")
  io.flush()
  local status, rv = pcall(fn)
  if status then
    put(" Done.\n")
    io.flush()
  else
    put("\n")
    io.flush()
    error(rv)
  end
  return rv
end

local function removetree(base)
  if fs.attributes(base, "mode") == "directory" then
    for file in fs.dir(base) do
      local sub = base .. "/" .. file
      if file ~= "." and file ~= ".." then
        if fs.attributes(sub, "mode") == "directory" then
          removetree(sub)
        else
          os.remove(sub)
        end
      end
    end
    fs.rmdir(base)
  else
    os.remove(base)
  end
end

local function reportcall(...)
  local args = table.pack(...)
  for i = 1, args.n do
    local status, rv = pcall(args[i])
    if not status then
      report(rv .. "\n")
    end
  end
end

local function reportindex(index, key)
  if index[key] == nil then
    report("Plugin " .. quote(key) .. " does not exist in the index file.\n")
  end
end

local function getindex()
  return json.decode(consume(SELF_INDEX_PATH))
end

--

local curl = {
  download = function(url, target)
    local success = sh.exec("curl", "--silent", "--output", target, "--", url)
    if not success then
      error("Downloading " .. quote(url) .. " failed.")
    end
  end
}

local git = {
  clone = function(url, target)
    local success = sh.exec("git", "clone", "--quiet", "--", url, target)
    if not success then
      error("Cloning " .. quote(url) .. " failed.")
    end
  end,

  pull = function(target)
    local success = sh.exec("git", "-C", target, "pull", "--quiet")
    if not success then
      error("Pulling " .. quote(target) .. " failed.")
    end
  end
}

local Plugin = {}

function Plugin:new(key, kind, urls)
  local o = {}
  setmetatable(o, self)
  self.__index = self
  self.key = key
  self.kind = kind
  self.urls = urls
  return o
end

function Plugin:install(target)
  for i, url in ipairs(self.urls) do
    if self:is_installed(target) then
      error("Plugin " .. quote(self.key) .. " is already installed.")
    end

    local desc = nil
    if i == 1 then
      desc = "Installing " .. quote(self.key) .. " via " .. quote(self.kind)
    else
      desc = "Retrying installation of " .. quote(self.key) .. " with a different mirror via " .. quote(self.kind)
    end

    verbose(desc, function()
      local actions = {
        file = function()
          return curl.download(url, target)
        end,
        git = function()
          return git.clone(url, target)
        end
      }

      if actions[self.kind] == nil then
        error("Invalid value for kind from " .. quote(self.key) .. ": " .. quote(self.kind))
      end

      local status, err = pcall(actions[self.kind])
      if not status then
        error(err)
      end
    end)
  end
end

function Plugin:remove(target)
  verbose("Removing " .. quote(self.key), function()
    removetree(target)
  end)
end

function Plugin:activate(target, link)
  if not self:is_installed(target) then
    error("Plugin " .. quote(self.key) .. " is not installed.")
  end
  if self:is_activated(target, link) then
    error("Plugin " .. quote(self.key) .. " is already activated.")
  end
  local attr = fs.symlinkattributes(link)
  if attr then
    error("File " .. quote(link) .. " is conflicting with the target path for " .. quote(self.key) .. ".")
  end
  verbose("Activating " .. quote(self.key), function()
    fs.link(target, link, true)
  end)
end

function Plugin:deactivate(target, link)
  local attr = fs.symlinkattributes(link)
  if not self:is_installed(target) then
    if attr then
      error("Refusing to remove " .. quote(link) .. " due to it not being a link for " .. quote(self.key) .. ".")
    else
      error("Plugin " .. quote(self.key) .. " is not installed.")
    end
  end
  if not self:is_activated(target, link) then
    error("Plugin " .. quote(self.key) .. " is not activated.")
  end
  verbose("Deactivating " .. quote(self.key), function()
    os.remove(link)
  end)
end

function Plugin:update(target)
  for i, url in ipairs(self.urls) do
    local desc = nil
    if i == 1 then
      desc = "Updating " .. quote(self.key) .. " via " .. quote(self.kind)
    else
      desc = "Retrying update of " .. quote(self.key) .. " with a different mirror via " .. quote(self.kind)
    end

    verbose(desc, function()
      local actions = {
        file = function()
          return curl.download(url, target)
        end,
        git = function()
          if i == 1 then
            return git.pull(target)
          else
            reportcall(function()
              self:remove(target)
            end)
            return git.clone(url, target)
          end
        end
      }

      if actions[self.kind] == nil then
        error("Invalid value for kind from " .. quote(self.key) .. ": " .. quote(self.kind))
      end

      local status, err = pcall(actions[self.kind])
      if not status then
        error(err)
      end
    end)
  end
end

function Plugin:is_installed(target)
  if fs.attributes(target) ~= nil then
    local actions = {
      file = function()
        return fs.attributes(target, "mode") == "file"
      end,
      git = function()
        return fs.attributes(target .. "/.git", "mode") == "directory"
      end
    }

    if actions[self.kind] == nil then
      error("Invalid value for kind from " .. quote(self.key) .. ": " .. quote(self.kind))
    end

    return actions[self.kind]()
  end
  return false
end

function Plugin:is_activated(target, link)
  local attr = fs.symlinkattributes(link)
  if not attr then
    return false
  end
  if attr.mode == "link" and attr.target == target then
    return true
  end
  return false
end

function Plugin.search(index, ...)
  local result = {}
  for key, _ in pairs(index) do
    local match = true
    local patterns = table.pack(...)
    for i = 1, patterns.n do
      if string.match(key, patterns[i]) == nil then
        match = false
        break
      end
    end
    if match then
      table.insert(result, key)
    end
  end
  return result
end

-- cli

local parser = argparse("lite-plug", "A bare-bones plugin manager for Lite XL")

local install = parser:command("install", "Install a plugin.")
  :action(function(args, name)
    local index = getindex()
    for _, key in pairs(args["plugin"]) do
      reportindex(index, key)

      local target = SELF_PLUGIN_DIR .. "/" .. key
      local plugin = Plugin:new(key, index[key]["kind"], index[key]["urls"])
      local link = LITE_PLUGIN_DIR .. "/" .. key

      if args["reinstall"] then
        reportcall(function()
          return plugin:remove(target)
        end)
      end

      reportcall(
        function()
          return plugin:install(target)
        end,
        function()
          if not plugin:is_activated(target, link) then
            return plugin:activate(target, link)
          end
        end
      )
    end
  end)
install:argument("plugin", "Plugin to install.")
  :args("1+")
install:flag("-r --reinstall", "Reinstall the plugin.")
  :action("store_true")

local remove = parser:command("remove", "Remove a plugin.")
  :action(function(args, name)
    local index = getindex()
    for _, key in pairs(args["plugin"]) do
      reportindex(index, key)

      local target = SELF_PLUGIN_DIR .. "/" .. key
      local plugin = Plugin:new(key, index[key]["kind"], index[key]["urls"])
      local link = LITE_PLUGIN_DIR .. "/" .. key

      reportcall(
        function() return plugin:deactivate(target, link) end,
        function() return plugin:remove(target) end
      )
    end
  end)
remove:argument("plugin", "Plugin to deactivate.")
  :args("1+")

local activate = parser:command("activate", "Activate a plugin.")
  :action(function(args, name)
    local index = getindex()
    for _, key in pairs(args["plugin"]) do
      reportindex(index, key)

      local target = SELF_PLUGIN_DIR .. "/" .. key
      local plugin = Plugin:new(key, index[key]["kind"], index[key]["urls"])
      local link = LITE_PLUGIN_DIR .. "/" .. key
      reportcall(function()
        return plugin:activate(target, link)
      end)
    end
  end)
activate:argument("plugin", "Plugin to activate.")
  :args("1+")

local deactivate = parser:command("deactivate", "Deactivate a plugin.")
  :action(function(args, name)
    local index = getindex()
    for _, key in pairs(args["plugin"]) do
      reportindex(index, key)

      local plugin = Plugin:new(key, index[key]["kind"], index[key]["urls"])
      local target = SELF_PLUGIN_DIR .. "/" .. key
      local link = LITE_PLUGIN_DIR .. "/" .. key
      reportcall(function()
        return plugin:deactivate(target, link)
      end)
    end
  end)
deactivate:argument("plugin", "Plugin to deactivate.")
  :args("1+")

local update = parser:command("update", "Update installed plugins.")
  :action(function(name)
    local index = getindex()
    for key, _ in pairs(index) do
      local plugin = Plugin:new(key, index[key]["kind"], index[key]["urls"])
      local target = SELF_PLUGIN_DIR .. "/" .. key

      if plugin:is_installed(target) then
        reportcall(function()
          return plugin:update(target)
        end)
      end
    end
  end)

local search = parser:command("search", "Search for plugins.")
  :action(function(args, name)
    local index = getindex()
    for _, result in ipairs(Plugin.search(index, table.unpack(args["pattern"]))) do
      put(quote(result) .. "\n")
    end
  end)
search:argument("pattern", "Search query as a Lua pattern. A plugin name must match all patterns.")
  :args("1+")

parser:parse()
