--// Mad City Chapter 1 Stats Logger
--// Persistent Cash watcher + Discord webhook
--// Configuration is provided through getgenv()

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local env = getgenv and getgenv() or _G

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local WEBHOOK = env.MadCityWebhook
local MIN_GAIN = tonumber(env.MadCityMinGain) or 10000

local SCRIPT_URL =
    "https://raw.githubusercontent.com/lastunitedc-eng/madcitystats/main/script.lua"

--------------------------------------------------
-- CHECK CONFIG
--------------------------------------------------

if not WEBHOOK or WEBHOOK == "" then
    error(
        "[MadCity Stats] Missing getgenv().MadCityWebhook"
    )
end

print("[MadCity Stats] Starting...")
print("[MadCity Stats] Minimum gain:", MIN_GAIN)

--------------------------------------------------
-- REQUEST FUNCTION
--------------------------------------------------

local requestFunc =
    request
    or http_request
    or (http and http.request)
    or (syn and syn.request)
    or (fluxus and fluxus.request)

if not requestFunc then
    error(
        "[MadCity Stats] No supported HTTP request function found."
    )
end

--------------------------------------------------
-- QUEUE SCRIPT AFTER SERVER HOP
--------------------------------------------------

local queueTeleport =
    queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)

if queueTeleport then

    -- Only queue once for the current server.
    if not env.MadCityStatsQueued then

        env.MadCityStatsQueued = true

        local queuedCode = string.format([[
            repeat
                task.wait()
            until game:IsLoaded()

            task.wait(2)

            -- Restore config in the new server
            getgenv().MadCityWebhook = %q
            getgenv().MadCityMinGain = %d

            -- Allow the newly loaded script to queue
            -- itself for the NEXT teleport.
            getgenv().MadCityStatsQueued = nil

            -- Clear old state
            getgenv().MadCityStatsRunning = nil
            getgenv().MadCityCashConnection = nil

            loadstring(game:HttpGet(%q))()
        ]],
            WEBHOOK,
            MIN_GAIN,
            SCRIPT_URL
        )

        local queuedSuccess, queuedError = pcall(function()
            queueTeleport(queuedCode)
        end)

        if queuedSuccess then
            print(
                "[MadCity Stats] Queued for next server hop."
            )
        else
            warn(
                "[MadCity Stats] Failed to queue after teleport:",
                queuedError
            )
        end

    end

else

    warn(
        "[MadCity Stats] queue_on_teleport isn't available."
    )

end

--------------------------------------------------
-- PREVENT DUPLICATE INSTANCE
--------------------------------------------------

if env.MadCityStatsRunning then
    warn(
        "[MadCity Stats] Logger already running in this server."
    )
    return
end

env.MadCityStatsRunning = true

--------------------------------------------------
-- REMOVE OLD CONNECTION
--------------------------------------------------

if env.MadCityCashConnection then

    pcall(function()
        env.MadCityCashConnection:Disconnect()
    end)

    env.MadCityCashConnection = nil
end

--------------------------------------------------
-- WAIT FOR LEADERSTATS
--------------------------------------------------

print("[MadCity Stats] Waiting for leaderstats...")

local leaderstats =
    Player:WaitForChild("leaderstats", 60)

if not leaderstats then

    env.MadCityStatsRunning = false

    error(
        "[MadCity Stats] leaderstats was not found."
    )
end

--------------------------------------------------
-- CASH + RANK
--------------------------------------------------

local Cash =
    leaderstats:WaitForChild("Cash", 30)

local Rank =
    leaderstats:WaitForChild("Rank", 30)

if not Cash then

    env.MadCityStatsRunning = false

    error(
        "[MadCity Stats] Cash was not found."
    )
end

if not Rank then

    env.MadCityStatsRunning = false

    error(
        "[MadCity Stats] Rank was not found."
    )
end

print("[MadCity Stats] leaderstats found.")
print("[MadCity Stats] Current Cash:", Cash.Value)
print("[MadCity Stats] Current Rank:", Rank.Value)

--------------------------------------------------
-- NUMBER FORMATTER
--------------------------------------------------

local function formatNumber(number)

    local num = tonumber(number) or 0

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
-- WEBHOOK URL
--------------------------------------------------

local function getWebhookURL()

    if WEBHOOK:find("?", 1, true) then
        return WEBHOOK .. "&wait=true"
    end

    return WEBHOOK .. "?wait=true"
end

--------------------------------------------------
-- SEND DISCORD MESSAGE
--------------------------------------------------

local function sendStats(gained, currentCash)

    local payload = {
        username = "Mad City Stats",

        embeds = {
            {
                title = "💰 Mad City Cash Update",

                description =
                    "**" .. Player.DisplayName .. "**\n" ..
                    "@" .. Player.Name,

                color = 5763719,

                fields = {
                    {
                        name = "💵 Cash Gained",
                        value =
                            "+$" ..
                            formatNumber(gained),

                        inline = true
                    },

                    {
                        name = "💰 Current Cash",
                        value =
                            "$" ..
                            formatNumber(currentCash),

                        inline = true
                    },

                    {
                        name = "⭐ Rank",
                        value =
                            tostring(Rank.Value),

                        inline = true
                    },

                    {
                        name = "👤 Username",
                        value = Player.Name,
                        inline = true
                    },

                    {
                        name = "🆔 User ID",
                        value =
                            tostring(Player.UserId),

                        inline = true
                    }
                },

                footer = {
                    text =
                        "Cash threshold: $" ..
                        formatNumber(MIN_GAIN)
                },

                timestamp =
                    os.date(
                        "!%Y-%m-%dT%H:%M:%SZ"
                    )
            }
        }
    }

    local encoded

    local encodeSuccess, encodeError =
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

        return
    end

    --------------------------------------------------
    -- SEND
    --------------------------------------------------

    local success, response =
        pcall(function()

            return requestFunc({
                Url = getWebhookURL(),

                Method = "POST",

                Headers = {
                    ["Content-Type"] =
                        "application/json"
                },

                Body = encoded
            })

        end)

    if not success then

        warn(
            "[MadCity Stats] Webhook failed:",
            response
        )

        return
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
        "| Gained:",
        gained,
        "| Cash:",
        currentCash,
        "| Status:",
        status or "unknown"
    )

    if status
        and status ~= 200
        and status ~= 204
    then

        warn(
            "[MadCity Stats] Discord HTTP error:",
            status
        )

        if response.Body then
            print(response.Body)
        elseif response.body then
            print(response.body)
        end

    end
end

--------------------------------------------------
-- CASH WATCHER
--------------------------------------------------

local lastCash =
    tonumber(Cash.Value) or 0

local accumulatedGain = 0

env.MadCityCashConnection =
    Cash:GetPropertyChangedSignal("Value")
        :Connect(function()

            --------------------------------------------------
            -- NEW VALUE
            --------------------------------------------------

            local currentCash =
                tonumber(Cash.Value)

            if not currentCash then
                return
            end

            --------------------------------------------------
            -- DIFFERENCE
            --------------------------------------------------

            local difference =
                currentCash - lastCash

            --------------------------------------------------
            -- ONLY COUNT POSITIVE GAINS
            --------------------------------------------------

            if difference > 0 then

                accumulatedGain += difference

                print(
                    "[MadCity Stats] +$" ..
                    formatNumber(difference),

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
                -- THRESHOLD HIT
                --------------------------------------------------

                if accumulatedGain >= MIN_GAIN then

                    local gained =
                        accumulatedGain

                    accumulatedGain = 0

                    task.spawn(function()

                        local sendSuccess,
                              sendError =
                            pcall(function()

                                sendStats(
                                    gained,
                                    currentCash
                                )

                            end)

                        if not sendSuccess then

                            warn(
                                "[MadCity Stats] Send error:",
                                sendError
                            )

                        end
                    end)

                end
            end

            --------------------------------------------------
            -- UPDATE PREVIOUS CASH
            --------------------------------------------------

            lastCash = currentCash

        end)

--------------------------------------------------
-- READY
--------------------------------------------------

print(
    "[MadCity Stats] Cash watcher running."
)

print(
    "[MadCity Stats] Discord notification every +$" ..
    formatNumber(MIN_GAIN) ..
    " earned."
)

if queueTeleport then

    print(
        "[MadCity Stats] Server-hop persistence enabled."
    )

else

    print(
        "[MadCity Stats] Server-hop persistence unavailable."
    )

end
