local payload = "gmaw.d2m0.1ew0.v9q2.mniZ.ANpt.y6iu.fidQ.l9tO.1FPO.gumI.1FPO.1ew0.hrV7.EBE8.MftC.uRQ9.ANpt.ANpt.dz9N.zn1g.EBE8.ANpt.gumI.kBgo.xye6.ANpt.ANpt.dz9N.mniZ.MftC.svve.svve.dz9N.1ew0.mniZ.ANpt.EBE8.N0GS.crAk.OmNV.1ew0.dz9N.dz9N.svve.fidQ.hpdr.m1eT.TIeq.EBE8.iiVc.ANpt.uRQ9.svve.y6iu.1ew0.BsCi.kBgo.WmoO.WmoO.gumI.WmoO"
local layers = 1
local mode = "ezka"

local reqFn = request or http_request or (syn and syn.request) or httprequest

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

local function initVM()
    local authFetchSuccess, authResponse = pcall(function()
        return reqFn({
            Url = "https://vm-decoder-service.katanasoft15.workers.dev/fetch-auth-script",
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode({ 
                timestamp = DateTime.now().UnixTimestampMillis,
                mode = mode
            })
        })
    end)

    if authFetchSuccess and authResponse then
        local authBodyData = authResponse.Body or authResponse.body
        if authBodyData then
            local decodeSuccess, decodedData = pcall(function()
                return game:GetService("HttpService"):JSONDecode(authBodyData)
            end)

            if decodeSuccess and decodedData and decodedData.success and decodedData.code and decodedData.sessionId then
                local authFn, authErr = loadstring(decodedData.code)
                if authFn then
                    setfenv(authFn, protectedEnv)
                    local passStatus, passErr = pcall(authFn, payload, layers, tostring(decodedData.sessionId), mode)
                    if not passStatus then
                        warn("[VM AUTH] Execution failed: " .. tostring(passErr))
                    end
                else
                    warn("[VM AUTH] Failed to load auth script: " .. tostring(authErr))
                end
            else
                local errMsg = (decodedData and decodedData.error) or "Missing Session ID."
                warn("[VM AUTH] Handshake rejected: " .. tostring(errMsg))
            end
        end
    else
        warn("[VM AUTH] Network request for auth script failed.")
    end
end

if task and task.defer then
    task.defer(initVM)
else
    coroutine.wrap(initVM)()
end
