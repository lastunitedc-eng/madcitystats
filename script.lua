--// Mad City Persistent Auto Execute
--// Re-runs after server hops

local env = getgenv()

--------------------------------------------------
-- CONFIG
--------------------------------------------------

env.MadCityWebhook = "PUT_YOUR_NEW_WEBHOOK_HERE"
env.MadCityMinGain = 10000

_G.AutorobIn = "public"

--------------------------------------------------
-- URLS
--------------------------------------------------

local STATS_URL =
    "https://raw.githubusercontent.com/lastunitedc-eng/madcitystats/main/script.lua"

local AUTOROB_URL =
    "https://raw.githubusercontent.com/aymarko/RubyHub/main/MadCity/Chapter1/Autorob.lua"

--------------------------------------------------
-- QUEUE AFTER TELEPORT
--------------------------------------------------

local queueTeleport =
    queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)

if queueTeleport then

    local queuedScript = [[
        repeat task.wait() until game:IsLoaded()
        task.wait(2)

        getgenv().MadCityWebhook = "PUT_YOUR_NEW_WEBHOOK_HERE"
        getgenv().MadCityMinGain = 10000

        _G.AutorobIn = "public"

        --------------------------------------------------
        -- STATS
        --------------------------------------------------

        task.spawn(function()
            local success, err = pcall(function()
                loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/lastunitedc-eng/madcitystats/main/script.lua"
                ))()
            end)

            if not success then
                warn("[Stats] Failed:", err)
            end
        end)

        --------------------------------------------------
        -- AUTOROB
        --------------------------------------------------

        task.spawn(function()
            task.wait(2)

            local success, err = pcall(function()
                loadstring(game:HttpGet(
                    "https://raw.githubusercontent.com/aymarko/RubyHub/main/MadCity/Chapter1/Autorob.lua"
                ))()
            end)

            if not success then
                warn("[RubyHub] Failed:", err)
            end
        end)
    ]]

    queueTeleport(queuedScript)

    print("[Mad City] Queued for next server hop.")
else
    warn("[Mad City] queue_on_teleport is not supported by this executor.")
end

--------------------------------------------------
-- START STATS NOW
--------------------------------------------------

task.spawn(function()

    local success, err = pcall(function()
        loadstring(game:HttpGet(STATS_URL))()
    end)

    if not success then
        warn("[Stats] Failed:", err)
    end

end)

--------------------------------------------------
-- START AUTOROB NOW
--------------------------------------------------

task.spawn(function()

    task.wait(2)

    local success, err = pcall(function()
        loadstring(game:HttpGet(AUTOROB_URL))()
    end)

    if not success then
        warn("[RubyHub] Failed:", err)
    end

end)

print("[Mad City] Everything started.")
