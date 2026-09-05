--// Mad City Chapter 1 Stats Logger
--// Cash milestone + timer + server-hop persistence

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
-- FILESYSTEM
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
-- LOAD CONFIG
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
-- STATE
--------------------------------------------------

local accumulatedGain = 0

-- Unix timestamp for when the current earning cycle began
local cycleStartedAt = os.time()

--------------------------------------------------
-- LOAD SAVED STATE
--------------------------------------------------

if hasFilesystem and fileExists(STATE_FILE) then

    local success, data = pcall(function()

        return HttpService:JSONDecode(
            readfile(STATE_FILE)
        )

    end)

    if success and type(data) == "table" then

        if tonumber(data.UserId) == Player.UserId then

            accumulatedGain =
                tonumber(data.AccumulatedGain)
                or 0

            cycleStartedAt =
                tonumber(data.CycleStartedAt)
                or os.time()

        end

    end

else

    -- Fallback for same executor environment
    accumulatedGain =
        tonumber(env.MadCityAccumulatedGain)
        or 0

    cycleStartedAt =
        tonumber(env.MadCityCycleStartedAt)
        or os.time()

end

--------------------------------------------------
-- SAVE STATE
--------------------------------------------------

local function saveState()

    env.MadCityAccumulatedGain =
        accumulatedGain

    env.MadCityCycleStartedAt =
        cycleStartedAt

    if not hasFilesystem then
        return
    end

    pcall(function()

        writefile(
            STATE_FILE,

            HttpService:JSONEncode({
                UserId = Player.UserId,

                AccumulatedGain =
                    accumulatedGain,

                CycleStartedAt =
                    cycleStartedAt,

                MinGain =
                    MIN_GAIN
            })
        )

    end)

end

saveState()

--------------------------------------------------
-- FORMAT NUMBER
--------------------------------------------------

local function formatNumber(number)

    local num =
        tonumber(number) or 0

    local str =
        tostring(math.floor(num))

    while true do

        local newString, count =
            str:gsub(
                "^(-?%d+)(%d%d%d)",
                "%1,%2"
            )

        str = newString

        if count == 0 then
            break
        end

    end

    return str
end

--------------------------------------------------
-- FORMAT TIME
--------------------------------------------------

local function formatDuration(seconds)

    seconds =
        math.max(
            0,
            math.floor(
                tonumber(seconds) or 0
            )
        )

    local days =
        math.floor(seconds / 86400)

    seconds =
        seconds % 86400

    local hours =
        math.floor(seconds / 3600)

    seconds =
        seconds % 3600

    local minutes =
        math.floor(seconds / 60)

    local secs =
        seconds % 60

    if days > 0 then

        return string.format(
            "%dd %dh %dm %ds",
            days,
            hours,
            minutes,
            secs
        )

    elseif hours > 0 then

        return string.format(
            "%dh %dm %ds",
            hours,
            minutes,
            secs
        )

    elseif minutes > 0 then

        return string.format(
            "%dm %ds",
            minutes,
            secs
        )

    else

        return string.format(
            "%ds",
            secs
        )

    end
end

--------------------------------------------------
-- START INFO
--------------------------------------------------

print("[MadCity Stats] Starting...")
print(
    "[MadCity Stats] Minimum gain:",
    MIN_GAIN
)

print(
    "[MadCity Stats] Saved progress:",
    accumulatedGain
)

print(
    "[MadCity Stats] Current timer:",
    formatDuration(
        os.time() - cycleStartedAt
    )
)

--------------------------------------------------
-- HTTP
--------------------------------------------------

local requestFunc =
    request
    or http_request
    or (http and http.request)
    or (syn and syn.request)
    or (fluxus and fluxus.request)

if not requestFunc then

    error(
        "[MadCity Stats] No HTTP request function."
    )

end

--------------------------------------------------
-- QUEUE ON TELEPORT
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
        -- FILESYSTEM VERSION
        --------------------------------------------------

        if hasFilesystem then

            queuedCode =
                string.format([[
                    repeat
                        task.wait()
                    until game:IsLoaded()

                    task.wait(2)

                    getgenv().MadCityStatsQueued = nil
                    getgenv().MadCityStatsRunning = nil
                    getgenv().MadCityCashConnection = nil
                    getgenv().MadCityTimerRunning = nil

                    loadstring(game:HttpGet(%q))()
                ]],
                    SCRIPT_URL
                )

        --------------------------------------------------
        -- FALLBACK
        --------------------------------------------------

        else

            queuedCode =
                string.format([[
                    repeat
                        task.wait()
                    until game:IsLoaded()

                    task.wait(2)

                    getgenv().MadCityWebhook = %q
                    getgenv().MadCityMinGain = %d

                    getgenv().MadCityAccumulatedGain = %d
                    getgenv().MadCityCycleStartedAt = %d

                    getgenv().MadCityStatsQueued = nil
                    getgenv().MadCityStatsRunning = nil
                    getgenv().MadCityCashConnection = nil
                    getgenv().MadCityTimerRunning = nil

                    loadstring(game:HttpGet(%q))()
                ]],
                    WEBHOOK,
                    MIN_GAIN,
                    accumulatedGain,
                    cycleStartedAt,
                    SCRIPT_URL
                )

        end

        local success, err =
            pcall(function()

                queueTeleport(
                    queuedCode
                )

            end)

        if success then

            print(
                "[MadCity Stats] Queued for next server hop."
            )

        else

            warn(
                "[MadCity Stats] Teleport queue failed:",
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
-- PREVENT DUPLICATE
--------------------------------------------------

if env.MadCityStatsRunning then

    warn(
        "[MadCity Stats] Already running."
    )

    return
end

env.MadCityStatsRunning = true

--------------------------------------------------
-- REMOVE OLD CONNECTION
--------------------------------------------------

if env.MadCityCashConnection then

    pcall(function()

        env.MadCityCashConnection:
            Disconnect()

    end)

    env.MadCityCashConnection = nil

end

--------------------------------------------------
-- WAIT FOR LEADERSTATS
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

if not Cash or not Rank then

    env.MadCityStatsRunning = false

    error(
        "[MadCity Stats] Cash or Rank not found."
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
-- WEBHOOK URL
--------------------------------------------------

local function getWebhookURL()

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
-- SEND WEBHOOK
--------------------------------------------------

local function sendWebhook(
    gained,
    currentCash,
    elapsed
)

    local payload = {

        username =
            "Mad City Stats",

        embeds = {
            {

                title =
                    "💰 Mad City Cash Update",

                description =
                    "**" ..
                    Player.DisplayName ..
                    "**\n@" ..
                    Player.Name,

                color =
                    5763719,

                fields = {

                    {
                        name =
                            "💵 Cash Gained",

                        value =
                            "+$" ..
                            formatNumber(
                                gained
                            ),

                        inline =
                            true
                    },

                    {
                        name =
                            "⏱️ Time Taken",

                        value =
                            formatDuration(
                                elapsed
                            ),

                        inline =
                            true
                    },

                    {
                        name =
                            "💰 Current Cash",

                        value =
                            "$" ..
                            formatNumber(
                                currentCash
                            ),

                        inline =
                            true
                    },

                    {
                        name =
                            "⭐ Rank",

                        value =
                            tostring(
                                Rank.Value
                            ),

                        inline =
                            true
                    },

                    {
                        name =
                            "👤 Username",

                        value =
                            Player.Name,

                        inline =
                            true
                    },

                    {
                        name =
                            "🆔 User ID",

                        value =
                            tostring(
                                Player.UserId
                            ),

                        inline =
                            true
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

    local encoded

    local encodeSuccess,
          encodeError =
        pcall(function()

            encoded =
                HttpService:JSONEncode(
                    payload
                )

        end)

    if not encodeSuccess then

        warn(
            "[MadCity Stats] JSON error:",
            encodeError
        )

        return false
    end

    local success,
          response =
        pcall(function()

            return requestFunc({

                Url =
                    getWebhookURL(),

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
        "| Gained:",
        gained,
        "| Time:",
        formatDuration(elapsed),
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
-- CASH WATCHER
--------------------------------------------------

local lastCash =
    tonumber(Cash.Value)
    or 0

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
        -- ONLY POSITIVE GAINS
        --------------------------------------------------

        if difference > 0 then

            accumulatedGain +=
                difference

            saveState()

            local elapsed =
                os.time() -
                cycleStartedAt

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
                ),

                "| Time:",
                formatDuration(
                    elapsed
                )
            )

            --------------------------------------------------
            -- THRESHOLD REACHED
            --------------------------------------------------

            if accumulatedGain >= MIN_GAIN then

                local gained =
                    accumulatedGain

                local oldStartedAt =
                    cycleStartedAt

                local timeTaken =
                    os.time() -
                    oldStartedAt

                --------------------------------------------------
                -- RESET NEXT CYCLE
                --------------------------------------------------

                accumulatedGain = 0
                cycleStartedAt = os.time()

                saveState()

                task.spawn(function()

                    local sent =
                        sendWebhook(
                            gained,
                            currentCash,
                            timeTaken
                        )

                    --------------------------------------------------
                    -- RESTORE IF SEND FAILED
                    --------------------------------------------------

                    if not sent then

                        accumulatedGain +=
                            gained

                        cycleStartedAt =
                            oldStartedAt

                        saveState()

                        warn(
                            "[MadCity Stats] Webhook failed; progress + timer restored."
                        )

                    end

                end)

            end
        end

        lastCash =
            currentCash

    end)

--------------------------------------------------
-- LIVE TIMER IN CONSOLE
--------------------------------------------------

env.MadCityTimerRunning = true

task.spawn(function()

    while env.MadCityTimerRunning
        and env.MadCityStatsRunning
    do

        task.wait(10)

        if not env.MadCityStatsRunning then
            break
        end

        print(
            "[MadCity Stats] Progress: $" ..
            formatNumber(
                accumulatedGain
            ) ..
            " / $" ..
            formatNumber(
                MIN_GAIN
            ) ..
            " | Timer: " ..
            formatDuration(
                os.time() -
                cycleStartedAt
            )
        )

    end

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

print(
    "[MadCity Stats] Timer: " ..
    formatDuration(
        os.time() -
        cycleStartedAt
    )
)

if queueTeleport then

    print(
        "[MadCity Stats] Server-hop persistence enabled."
    )

end
