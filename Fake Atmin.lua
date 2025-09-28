local Versions = {
    V1 = "https://github.com/TlDinhKhoi/Xeter/raw/refs/heads/main/Version/V1.lua",
    V2 = "https://github.com/TlDinhKhoi/Xeter/raw/refs/heads/main/Version/V2.lua",
    V3 = "https://github.com/TlDinhKhoi/Xeter/raw/refs/heads/main/Version/V3.lua",
}

local ver = getgenv().Version or "V3"
loadstring(game:HttpGet(Versions[ver] or Versions.V3))()
