--// Mad City Chapter 1 Background Stats Logger

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local env = getgenv()
local Player = Players.LocalPlayer

--------------------------------------------------
-- CONFIG FROM GETGENV
--------------------------------------------------

local WEBHOOK = env.MadCityWebhook
local SEND_INTERVAL = tonumber(env.MadCityInterval) or 30

if not WEBHOOK or WEBHOOK == "" then
    error("[MadCity Stats] getgenv().MadCityWebhook is missing.")
end

--------------------------------------------------
-- DON'T START TWICE
--------------------------------------------------

if env.MadCityStatsRunning then
    warn("[MadCity Stats] Background logger is already running.")
    return
end

env.MadCityStatsRunning = true

--------------------------------------------------
-- HTTP FUNCTION
--------------------------------------------------

local requestFunc =
    request
    or http_request
    or (http and http.request)
    or (syn and syn.request)

if not requestFunc then
    env.MadCityStatsRunning = false
    error("[MadCity Stats] HTTP requests aren't supported.")
end

--------------------------------------------------
-- BACKGROUND THREAD
--------------------------------------------------

task.spawn(function()

    print("[MadCity Stats] Background logger started.")

    --------------------------------------------------
    -- WAIT FOR STATS
    --------------------------------------------------

    local leaderstats = Player:WaitForChild("leaderstats", 60)

    if not leaderstats then
        env.MadCityStatsRunning = false
        warn("[MadCity Stats] leaderstats not found.")
        return
    end

    local Cash = leaderstats:WaitForChild("Cash", 30)
    local Rank = leaderstats:WaitForChild("Rank", 30)

    if not Cash or not Rank then
        env.MadCityStatsRunning = false
        warn("[MadCity Stats] Cash or Rank not found.")
        return
    end

    --------------------------------------------------
    -- FORMAT CASH
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
    -- SEND STATS
    --------------------------------------------------

    local function sendStats()

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
                            "Background update • every " ..
                            tostring(SEND_INTERVAL) ..
                            " seconds"
                    },

                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }
        }

        local body = HttpService:JSONEncode(payload)

        local url = WEBHOOK

        if url:find("?", 1, true) then
            url = url .. "&wait=true"
        else
            url = url .. "?wait=true"
        end

        local success, response = pcall(function()
            return requestFunc({
                Url = url,
                Method = "POST",

                Headers = {
                    ["Content-Type"] = "application/json"
                },

                Body = body
            })
        end)

        if not success then
            warn("[MadCity Stats] Send failed:", response)
            return
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
            "[MadCity Stats] Sent | Cash:",
            cashValue,
            "| Rank:",
            rankValue,
            "| HTTP:",
            status or "unknown"
        )
    end

    --------------------------------------------------
    -- LOOP FOREVER
    --------------------------------------------------

    while env.MadCityStatsRunning do

        local success, err = pcall(sendStats)

        if not success then
            warn("[MadCity Stats] Background error:", err)
        end

        task.wait(SEND_INTERVAL)
    end

    print("[MadCity Stats] Background logger stopped.")

end)

print("[MadCity Stats] Script loaded. Running in background.")
