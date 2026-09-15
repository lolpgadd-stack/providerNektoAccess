local payloadId = "b49e8ae60353c336"
local layers = 1
local mode = "ezka"
local licenseKey = "RKO-MAIN-KEY-0001"

local reqFn = request or http_request or (syn and syn.request) or httprequest
local HttpSvc = game:GetService("HttpService")
local rkoHwid = ""


local function rkoHeaders(token)
    local h = {
        ["Content-Type"]   = "application/json",
        ["User-Agent"]     = "RKO",
        ["Cache-Control"]  = "no-cache",
        ["X-RKO-Timestamp"] = tostring(math.floor(os.time())),
        ["X-RKO-Nonce"]    = HttpSvc:GenerateGUID(false)
    }
    if rkoHwid ~= "" then h["X-RKO-Hwid"] = rkoHwid end
    if token then h["Authorization"] = "Bearer " .. token end
    return h
end

local function jsonDecode(str)
    local ok, d = pcall(function() return HttpSvc:JSONDecode(str or "") end)
    return ok and d or nil
end

local protectedEnv = setmetatable({
    game = game,
    workspace = workspace,
    script = script,
    setclipboard = function(...) error("[VM SECURITY] Clipboard access denied.") end,
    toclipboard = function(...) error("[VM SECURITY] Clipboard access denied.") end,
    writefile = function(...) error("[VM SECURITY] File writing denied.") end,
    appendfile = function(...) error("[VM SECURITY] File writing denied.") end,
    request = reqFn,
    http_request = reqFn,
    httprequest = reqFn
}, {
    __index = function(t, k)
        return getfenv(0)[k]
    end
})

local function post(path, token, bodyStr)
    local ok, res = pcall(function()
        return reqFn({ Url = "https://vm-decoder-service.katanasoft15.workers.dev" .. path, Method = "POST", Headers = rkoHeaders(token), Body = bodyStr })
    end)
    if not (ok and res) then return nil, tostring(res) end
    return jsonDecode(res.Body or res.body or "")
end

local function initVM()
   
    if getgenv then
        pcall(function() getgenv().ZenixPayloadId = payloadId end)
    end
    _G.ZenixPayloadId = payloadId
    _G.ZenixLayers    = layers
    _G.ZenixMode      = mode
    _G.ZenixLicenseKey = licenseKey

   
    local hwid = ""
    if gethwid then
        local okHW, val = pcall(gethwid)
        if okHW and type(val) == "string" and val ~= "" then hwid = val end
    end
    if hwid == "" then hwid = tostring(game:GetService("RbxAnalyticsService"):GetSessionId()) end
    rkoHwid = tostring(hwid)
    local clientId = HttpSvc:GenerateGUID(false)

    local loginData, loginErr = post("/v1/auth/login", nil, HttpSvc:JSONEncode({ licenseKey = licenseKey, hwid = tostring(hwid), clientId = tostring(clientId) }))
    if not (loginData and loginData.access_token) then
        warn("[VM AUTH] RKO login rejected: " .. tostring(loginData and loginData.error or loginErr))
        return
    end

    local rkoState = {
        accessToken = loginData.access_token,
        sessionId = loginData.session_id,
        placeId = tostring(game.PlaceId),
        jobId = tostring(game.JobId or tostring(game.PlaceId)),
        gameId = tostring(game.GameId),
        hwid = tostring(hwid),
        licenseKey = licenseKey
    }
    if getgenv then
        pcall(function() getgenv().ZenixRko = rkoState end)
    end
    _G.ZenixRko = rkoState

    
    if task and task.spawn then
        task.spawn(function()
            local interval = math.max(30, tonumber(loginData.heartbeat_interval_sec) or 180)
            while _G.ZenixRko and _G.ZenixRko.accessToken do
                task.wait(interval)
                pcall(post, "/v1/auth/heartbeat", _G.ZenixRko.accessToken, "{}")
            end
        end)
    end

    local authData = nil
    do
        local d, e = post("/fetch-auth-script", loginData.access_token, HttpSvc:JSONEncode({ timestamp = DateTime.now().UnixTimestampMillis, mode = mode }))
        if d then authData = d elseif e then warn("[VM AUTH] Handshake request failed: " .. tostring(e)) return end
    end

    if not (authData and authData.success and authData.code and authData.sessionId) then
        warn("[VM AUTH] Handshake rejected: " .. tostring(authData and authData.error or "Missing session ID."))
        return
    end

    local fn, ferr = loadstring(authData.code)
    if not fn then
        warn("[VM AUTH] Failed to load bridge: " .. tostring(ferr))
        return
    end

    setfenv(fn, protectedEnv)
    local ok, err = pcall(fn, nil, layers, tostring(authData.sessionId), mode)
    if not ok then
        warn("[VM AUTH] Bridge execution failed: " .. tostring(err))
    end
end

if task and task.defer then
    task.defer(initVM)
else
    coroutine.wrap(initVM)()
end
