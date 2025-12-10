local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local Request = http_request or request or HttpPost or syn.request

local RemoveErrorPrompts = true
local IterationSpeed = 0.1
local SaveTeleportAttempts = false
local MaxTeleportAttempts = 20
local MaxPages = 5
local MaxAllowedPlayers = 1
local LoopUntilLow = false

local function HttpGet(Url)
    local Response = Request({
        Url = Url,
        Method = "GET"
    })
    return Response.Body
end

local function GetFreshServerList(Cursor)
    local Url = "https://games.roblox.com/v1/games/" .. game.PlaceId ..
                "/servers/Public?limit=100&sortOrder=Asc"
    if Cursor then
        Url = Url .. "&cursor=" .. Cursor
    end

    local Response = HttpGet(Url)
    local Ok, Data = pcall(function()
        return HttpService:JSONDecode(Response)
    end)

    if Ok and Data and Data.data then
        return Data
    end

    return nil
end

local function FindOnePlayerServers(ServerList)
    if not ServerList or not ServerList.data then
        return {}
    end

    table.sort(ServerList.data, function(A, B)
        return (A.playing or 0) < (B.playing or 0)
    end)

    local OnePlayer = {}

    for _, Server in ipairs(ServerList.data) do
        local Count = Server.playing or 0
        if Count == 1 then
            table.insert(OnePlayer, Server)
        end
    end

    return OnePlayer
end

local function StartLowPopHop()
    local Attempts = 0
    local PagesFetched = 0
    local Cursor = nil

    while Attempts < MaxTeleportAttempts and PagesFetched < MaxPages do
        local ServerList = GetFreshServerList(Cursor)
        if not ServerList then
            task.wait(2)
            PagesFetched += 1
            continue
        end

        local TargetServers = FindOnePlayerServers(ServerList)

        if #TargetServers == 0 then
            if ServerList.nextPageCursor then
                Cursor = ServerList.nextPageCursor
                PagesFetched += 1
                task.wait(0.3)
                continue
            else
                break
            end
        end

        local Server = TargetServers[1]
        local JobId = Server.id
        local PlayerCount = Server.playing or 0

        Attempts += 1

        if SaveTeleportAttempts then
            appendfile("Attempts.txt", JobId .. " (" .. PlayerCount .. " players)\n")
        end

        pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, JobId, Players.LocalPlayer)
        end)

        task.wait(IterationSpeed)

        if not LoopUntilLow then
            return
        end

        return
    end

    TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
end

local function AutoRehopIfTooFull()
    if not LoopUntilLow then return end

    local function Check()
        local Count = #Players:GetPlayers()
        if Count > MaxAllowedPlayers then
            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        end
    end

    Players.LocalPlayer.CharacterAdded:Connect(function()
        task.delay(4, Check)
    end)

    if Players.LocalPlayer.Character then
        task.delay(4, Check)
    end
end

if RemoveErrorPrompts then
    pcall(function() CoreGui:WaitForChild("RobloxGui"):WaitForChild("Modules"):WaitForChild("ErrorPrompt"):Destroy() end)
    pcall(function() CoreGui.RobloxPromptGui:Destroy() end)
end

AutoRehopIfTooFull()
StartLowPopHop()
