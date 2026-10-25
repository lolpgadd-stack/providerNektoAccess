load = loadstring

getgenv().AuthGGKey = "AUTHGG-Y8RDY-THTYX-GYS5C-RWPPV"
getgenv().AuthGGBuild = "bld_b9687f76debe1ac63798"
local url = "https://authgg.xpcall.workers.dev/loader.luau?v=4"
task.defer(function()
    local source = game:HttpGet(url)
    local chunk = load(source, "AuthGGLoader")
    if not chunk then
        error("AuthGG: loader did not compile", 0)
    end
    task.defer(chunk)
end)
