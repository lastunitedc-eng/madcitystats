--// Mad City Chapter 1 Stats Logger
--// Config is supplied through getgenv()

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local env = getgenv and getgenv() or _G

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local WEBHOOK = env.MadCityWebhook
local SEND_INTERVAL = tonumber(env.MadCityInterval) or 30

if not WEBHOOK or WEBHOOK == "" then
    error("[MadCity Stats] getgenv().MadCityWebhook is not set.")
end

--------------------------------------------------
-- PREVENT DUPLICATE LOOPS
--------------------------------------------------

if env.MadCityStatsLoopRunning then
    warn("[MadCity Stats] Already running.")
    return
end

env.MadCityStatsLoopRunning = true

--------------------------------------------------
-- HTTP REQUEST
--------------------------------------------------

local requestFunc =
    request
    or http_request
    or (http and http.request)
    or (syn and syn.request)

if not requestFunc then
    env.MadCityStatsLoopRunning = false
    error("[MadCity Stats] HTTP request function not found.")
end

--------------------------------------------------
-- WAIT FOR STATS
--------------------------------------------------

print("[MadCity Stats] Waiting for leaderstats...")

local leaderstats = Player:WaitForChild("leaderstats", 30)

if not leaderstats then
    env.MadCityStatsLoopRunning = false
    error("[MadCity Stats] leaderstats not found.")
end

local Cash = leaderstats:WaitForChild("Cash", 30)
local Rank = leaderstats:WaitForChild("Rank", 30)

if not Cash or not Rank then
    env.MadCityStatsLoopRunning = false
    error("[MadCity Stats] Cash or Rank not found.")
end

print("[MadCity Stats] Stats found.")
print("[MadCity Stats] Interval:", SEND_INTERVAL)

--------------------------------------------------
-- FORMAT NUMBERS
--------------------------------------------------

local function formatNumber(number)
    local str = tostring(number)

    while true do
        local newStr, count =
            str:gsub("^(-?%d+)(%d%d%d)", "%1,%2")

        str = newStr

        if count == 0 then
            break
        end
    end

    return str
end

--------------------------------------------------
-- SEND
--------------------------------------------------

local function sendStats()

    if not Player.Parent then
        return
    end

    local cashValue = Cash.Value
    local rankValue = Rank.Value

    local payload = {
        username = "Mad City Stats",

        embeds = {
            {
                title = "Mad City: Chapter 1 Stats",

                description =
                    "**" .. Player.DisplayName .. "**\n" ..
                    "@" .. Player.Name,

                color = 5793266,

                fields = {
                    {
                        name = "💰 Cash",
                        value = "$" .. formatNumber(cashValue),
                        inline = true
                    },

                    {
                        name = "⭐ Rank",
                        value = tostring(rankValue),
                        inline = true
                    },

                    {
                        name = "👤 Username",
                        value = Player.Name,
                        inline = true
                    },

                    {
                        name = "🆔 User ID",
                        value = tostring(Player.UserId),
                        inline = true
                    }
                },

                footer = {
                    text =
                        "Updates every " ..
                        tostring(SEND_INTERVAL) ..
                        " seconds"
                },

                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }

    local body = HttpService:JSONEncode(payload)

    local webhookURL = WEBHOOK

    if webhookURL:find("?", 1, true) then
        webhookURL = webhookURL .. "&wait=true"
    else
        webhookURL = webhookURL .. "?wait=true"
    end

    local success, response = pcall(function()
        return requestFunc({
            Url = webhookURL,
            Method = "POST",

            Headers = {
                ["Content-Type"] = "application/json"
            },

            Body = body
        })
    end)

    if not success then
        warn("[MadCity Stats] Request failed:", response)
        return
    end

    if type(response) == "table" then
        local status =
            response.StatusCode
            or response.Status
            or response.status
            or response.status_code

        print(
            "[MadCity Stats] Sent | Cash:",
            cashValue,
            "| Rank:",
            rankValue,
            "| HTTP:",
            status or "unknown"
        )
    else
        print(
            "[MadCity Stats] Sent | Cash:",
            cashValue,
            "| Rank:",
            rankValue
        )
    end
end

--------------------------------------------------
-- START LOOP
--------------------------------------------------

sendStats()

while env.MadCityStatsLoopRunning do
    task.wait(SEND_INTERVAL)

    local success, err = pcall(sendStats)

    if not success then
        warn("[MadCity Stats] Error:", err)
    end
end
