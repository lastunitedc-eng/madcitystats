--// Mad City Chapter 1 Stats Logger
--// Cash milestone logger
--// Persists progress through server hops when executor filesystem is supported

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local env = getgenv and getgenv() or _G

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local SCRIPT_URL =
    "https://raw.githubusercontent.com/lastunitedc-eng/madcitystats/main/script.lua"

local CONFIG_FILE = "madcitystats_config.json"
local STATE_FILE = "madcitystats_state.json"

--------------------------------------------------
-- FILESYSTEM SUPPORT
--------------------------------------------------

local hasFilesystem =
    type(writefile) == "function"
    and type(readfile) == "function"

local function fileExists(path)
    if type(isfile) == "function" then
        local success, result = pcall(isfile, path)

        if success then
            return result
        end
    end

    if type(readfile) == "function" then
        return pcall(readfile, path)
    end

    return false
end

--------------------------------------------------
-- LOAD SAVED CONFIG
--------------------------------------------------

local savedConfig = {}

if hasFilesystem and fileExists(CONFIG_FILE) then
    pcall(function()
        savedConfig =
            HttpService:JSONDecode(
                readfile(CONFIG_FILE)
            )
    end)
end

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local WEBHOOK =
    env.MadCityWebhook
    or savedConfig.Webhook

local MIN_GAIN =
    tonumber(env.MadCityMinGain)
    or tonumber(savedConfig.MinGain)
    or 10000

if not WEBHOOK or WEBHOOK == "" then
    error(
        "[MadCity Stats] Missing getgenv().MadCityWebhook"
    )
end

env.MadCityWebhook = WEBHOOK
env.MadCityMinGain = MIN_GAIN

--------------------------------------------------
-- SAVE CONFIG
--------------------------------------------------

if hasFilesystem then
    pcall(function()

        writefile(
            CONFIG_FILE,

            HttpService:JSONEncode({
                Webhook = WEBHOOK,
                MinGain = MIN_GAIN
            })
        )

    end)
end

--------------------------------------------------
-- LOAD SAVED PROGRESS
--------------------------------------------------

local accumulatedGain = 0

if hasFilesystem and fileExists(STATE_FILE) then

    local success, data = pcall(function()

        return HttpService:JSONDecode(
            readfile(STATE_FILE)
        )

    end)

    if success and type(data) == "table" then

        if tonumber(data.UserId) == Player.UserId then
            accumulatedGain =
                tonumber(data.AccumulatedGain) or 0
        end

    end
end

--------------------------------------------------
-- SAVE PROGRESS
--------------------------------------------------

local function saveProgress()

    env.MadCityAccumulatedGain =
        accumulatedGain

    if not hasFilesystem then
        return
    end

    pcall(function()

        writefile(
            STATE_FILE,

            HttpService:JSONEncode({
                UserId = Player.UserId,
                AccumulatedGain = accumulatedGain,
                MinGain = MIN_GAIN
            })
        )

    end)

end

saveProgress()

--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("[MadCity Stats] Starting...")
print("[MadCity Stats] Minimum gain:", MIN_GAIN)
print(
    "[MadCity Stats] Saved progress:",
    accumulatedGain
)

if hasFilesystem then
    print(
        "[MadCity Stats] Persistent progress enabled."
    )
else
    warn(
        "[MadCity Stats] Executor filesystem unavailable."
    )

    warn(
        "[MadCity Stats] Progress may reset after server hops."
    )
end

--------------------------------------------------
-- HTTP REQUEST
--------------------------------------------------

local requestFunc =
    request
    or http_request
    or (http and http.request)
    or (syn and syn.request)
    or (fluxus and fluxus.request)

if not requestFunc then
    error(
        "[MadCity Stats] No HTTP request function found."
    )
end

--------------------------------------------------
-- QUEUE AFTER TELEPORT
--------------------------------------------------

local queueTeleport =
    queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)

if queueTeleport then

    if not env.MadCityStatsQueued then

        env.MadCityStatsQueued = true

        local queuedCode

        --------------------------------------------------
        -- FILESYSTEM MODE
        --------------------------------------------------

        if hasFilesystem then

            queuedCode = string.format([[
                repeat
                    task.wait()
                until game:IsLoaded()

                task.wait(2)

                getgenv().MadCityStatsQueued = nil
                getgenv().MadCityStatsRunning = nil
                getgenv().MadCityCashConnection = nil

                loadstring(game:HttpGet(%q))()
            ]],
                SCRIPT_URL
            )

        --------------------------------------------------
        -- FALLBACK MODE
        --------------------------------------------------

        else

            queuedCode = string.format([[
                repeat
                    task.wait()
                until game:IsLoaded()

                task.wait(2)

                getgenv().MadCityWebhook = %q
                getgenv().MadCityMinGain = %d

                getgenv().MadCityAccumulatedGain = %d

                getgenv().MadCityStatsQueued = nil
                getgenv().MadCityStatsRunning = nil
                getgenv().MadCityCashConnection = nil

                loadstring(game:HttpGet(%q))()
            ]],
                WEBHOOK,
                MIN_GAIN,
                accumulatedGain,
                SCRIPT_URL
            )

        end

        local success, err =
            pcall(function()
                queueTeleport(queuedCode)
            end)

        if success then
            print(
                "[MadCity Stats] Queued for next server hop."
            )
        else
            warn(
                "[MadCity Stats] queue_on_teleport error:",
                err
            )
        end
    end

else

    warn(
        "[MadCity Stats] queue_on_teleport unavailable."
    )

end

--------------------------------------------------
-- PREVENT DUPLICATE WATCHERS
--------------------------------------------------

if env.MadCityStatsRunning then
    warn(
        "[MadCity Stats] Already running."
    )
    return
end

env.MadCityStatsRunning = true

--------------------------------------------------
-- OLD CONNECTION
--------------------------------------------------

if env.MadCityCashConnection then

    pcall(function()
        env.MadCityCashConnection:Disconnect()
    end)

    env.MadCityCashConnection = nil
end

--------------------------------------------------
-- LEADERSTATS
--------------------------------------------------

print(
    "[MadCity Stats] Waiting for leaderstats..."
)

local leaderstats =
    Player:WaitForChild(
        "leaderstats",
        60
    )

if not leaderstats then

    env.MadCityStatsRunning = false

    error(
        "[MadCity Stats] leaderstats not found."
    )
end

--------------------------------------------------
-- CASH + RANK
--------------------------------------------------

local Cash =
    leaderstats:WaitForChild(
        "Cash",
        30
    )

local Rank =
    leaderstats:WaitForChild(
        "Rank",
        30
    )

if not Cash then

    env.MadCityStatsRunning = false

    error(
        "[MadCity Stats] Cash not found."
    )
end

if not Rank then

    env.MadCityStatsRunning = false

    error(
        "[MadCity Stats] Rank not found."
    )
end

print(
    "[MadCity Stats] leaderstats found."
)

print(
    "[MadCity Stats] Current Cash:",
    Cash.Value
)

print(
    "[MadCity Stats] Current Rank:",
    Rank.Value
)

--------------------------------------------------
-- NUMBER FORMAT
--------------------------------------------------

local function formatNumber(number)

    local num =
        tonumber(number) or 0

    local stringNumber =
        tostring(math.floor(num))

    while true do

        local newString, count =
            stringNumber:gsub(
                "^(-?%d+)(%d%d%d)",
                "%1,%2"
            )

        stringNumber = newString

        if count == 0 then
            break
        end
    end

    return stringNumber
end

--------------------------------------------------
-- WEBHOOK URL
--------------------------------------------------

local function webhookURL()

    if WEBHOOK:find(
        "?",
        1,
        true
    ) then

        return WEBHOOK ..
            "&wait=true"

    end

    return WEBHOOK ..
        "?wait=true"

end

--------------------------------------------------
-- SEND DISCORD
--------------------------------------------------

local function sendWebhook(
    gained,
    currentCash
)

    local payload = {
        username = "Mad City Stats",

        embeds = {
            {
                title =
                    "💰 Mad City Cash Update",

                description =
                    "**" ..
                    Player.DisplayName ..
                    "**\n@" ..
                    Player.Name,

                color = 5763719,

                fields = {
                    {
                        name =
                            "💵 Cash Gained",

                        value =
                            "+$" ..
                            formatNumber(
                                gained
                            ),

                        inline = true
                    },

                    {
                        name =
                            "💰 Current Cash",

                        value =
                            "$" ..
                            formatNumber(
                                currentCash
                            ),

                        inline = true
                    },

                    {
                        name = "⭐ Rank",

                        value =
                            tostring(
                                Rank.Value
                            ),

                        inline = true
                    },

                    {
                        name =
                            "👤 Username",

                        value =
                            Player.Name,

                        inline = true
                    },

                    {
                        name =
                            "🆔 User ID",

                        value =
                            tostring(
                                Player.UserId
                            ),

                        inline = true
                    }
                },

                footer = {
                    text =
                        "Threshold: $" ..
                        formatNumber(
                            MIN_GAIN
                        )
                },

                timestamp =
                    os.date(
                        "!%Y-%m-%dT%H:%M:%SZ"
                    )
            }
        }
    }

    --------------------------------------------------
    -- JSON
    --------------------------------------------------

    local successEncode,
          encoded =
        pcall(function()

            return HttpService:JSONEncode(
                payload
            )

        end)

    if not successEncode then

        warn(
            "[MadCity Stats] JSON error:",
            encoded
        )

        return false
    end

    --------------------------------------------------
    -- REQUEST
    --------------------------------------------------

    local success,
          response =
        pcall(function()

            return requestFunc({
                Url =
                    webhookURL(),

                Method =
                    "POST",

                Headers = {
                    ["Content-Type"] =
                        "application/json"
                },

                Body =
                    encoded
            })

        end)

    if not success then

        warn(
            "[MadCity Stats] Webhook failed:",
            response
        )

        return false
    end

    --------------------------------------------------
    -- RESPONSE
    --------------------------------------------------

    local status

    if type(response) == "table" then

        status =
            response.StatusCode
            or response.Status
            or response.status
            or response.status_code

    end

    print(
        "[MadCity Stats] Discord sent",
        "| Gain:",
        gained,
        "| Cash:",
        currentCash,
        "| HTTP:",
        status or "unknown"
    )

    if status
        and status ~= 200
        and status ~= 204
    then

        warn(
            "[MadCity Stats] HTTP error:",
            status
        )

        return false
    end

    return true
end

--------------------------------------------------
-- CURRENT CASH
--------------------------------------------------

local lastCash =
    tonumber(Cash.Value) or 0

--------------------------------------------------
-- RESTORE GETGENV FALLBACK
--------------------------------------------------

if not hasFilesystem then

    accumulatedGain =
        tonumber(
            env.MadCityAccumulatedGain
        )
        or accumulatedGain

end

saveProgress()

--------------------------------------------------
-- CASH WATCHER
--------------------------------------------------

env.MadCityCashConnection =
    Cash:GetPropertyChangedSignal(
        "Value"
    ):Connect(function()

        local currentCash =
            tonumber(Cash.Value)

        if not currentCash then
            return
        end

        local difference =
            currentCash - lastCash

        --------------------------------------------------
        -- POSITIVE CASH ONLY
        --------------------------------------------------

        if difference > 0 then

            accumulatedGain +=
                difference

            saveProgress()

            print(
                "[MadCity Stats] +$" ..
                formatNumber(
                    difference
                ),

                "| Progress: $" ..
                formatNumber(
                    accumulatedGain
                ) ..
                " / $" ..
                formatNumber(
                    MIN_GAIN
                )
            )

            --------------------------------------------------
            -- HIT THRESHOLD
            --------------------------------------------------

            if accumulatedGain >= MIN_GAIN then

                local gained =
                    accumulatedGain

                --------------------------------------------------
                -- RESET FIRST
                --------------------------------------------------

                accumulatedGain = 0
                saveProgress()

                task.spawn(function()

                    local sent =
                        sendWebhook(
                            gained,
                            currentCash
                        )

                    --------------------------------------------------
                    -- IF WEBHOOK FAILED, RESTORE PROGRESS
                    --------------------------------------------------

                    if not sent then

                        accumulatedGain +=
                            gained

                        saveProgress()

                        warn(
                            "[MadCity Stats] Restored progress because webhook failed."
                        )

                    end

                end)
            end
        end

        lastCash =
            currentCash
    end)

--------------------------------------------------
-- READY
--------------------------------------------------

print(
    "[MadCity Stats] Cash watcher running."
)

print(
    "[MadCity Stats] Progress: $" ..
    formatNumber(
        accumulatedGain
    ) ..
    " / $" ..
    formatNumber(
        MIN_GAIN
    )
)

if queueTeleport then

    print(
        "[MadCity Stats] Server-hop persistence enabled."
    )

end
