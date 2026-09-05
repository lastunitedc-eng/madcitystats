--// Mad City Chapter 1 -> Discord Stats
--// Auto Execute / Delta
--// Sends Cash + Rank every 30 seconds

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local WEBHOOK = "PUT_YOUR_NEW_WEBHOOK_HERE"
local SEND_INTERVAL = 30

--------------------------------------------------
-- PREVENT MULTIPLE LOOPS
--------------------------------------------------

local env = getgenv and getgenv() or _G

if env.MadCityStatsLoopRunning then
    warn("[MadCity Stats] Already running.")
    return
end

env.MadCityStatsLoopRunning = true

--------------------------------------------------
-- REQUEST FUNCTION
--------------------------------------------------

local requestFunc =
    request
    or http_request
    or (http and http.request)
    or (syn and syn.request)

if not requestFunc then
    env.MadCityStatsLoopRunning = false
    error("[MadCity Stats] No HTTP request function found.")
end

--------------------------------------------------
-- WAIT FOR LEADERSTATS
--------------------------------------------------

print("[MadCity Stats] Waiting for leaderstats...")

local leaderstats = Player:WaitForChild("leaderstats", 30)

if not leaderstats then
    env.MadCityStatsLoopRunning = false
    error("[MadCity Stats] leaderstats not found.")
end

local Cash = leaderstats:WaitForChild("Cash", 30)
local Rank = leaderstats:WaitForChild("Rank", 30)

if not Cash then
    env.MadCityStatsLoopRunning = false
    error("[MadCity Stats] Cash not found.")
end

if not Rank then
    env.MadCityStatsLoopRunning = false
    error("[MadCity Stats] Rank not found.")
end

print("[MadCity Stats] Stats found.")
print("[MadCity Stats] Sending every " .. SEND_INTERVAL .. " seconds.")

--------------------------------------------------
-- FORMAT NUMBER
--------------------------------------------------

local function formatNumber(num)
    local str = tostring(num)

    while true do
        local newString, count =
            str:gsub("^(-?%d+)(%d%d%d)", "%1,%2")

        str = newString

        if count == 0 then
            break
        end
    end

    return str
end

--------------------------------------------------
-- SEND FUNCTION
--------------------------------------------------

local function sendStats()

    local cashValue = Cash.Value
    local rankValue = Rank.Value

    print(
        "[MadCity Stats] Cash:",
        cashValue,
        "| Rank:",
        rankValue
    )

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
                    text = "Updates every 30 seconds"
                },

                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }

    local json = HttpService:JSONEncode(payload)

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

            Body = json
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

        if status == 200 or status == 204 then
            print("[MadCity Stats] Sent successfully.")
        else
            warn(
                "[MadCity Stats] HTTP status:",
                status or "unknown"
            )

            if response.Body then
                print(response.Body)
            end
        end

    else
        print("[MadCity Stats] Request completed.")
    end
end

--------------------------------------------------
-- LOOP
--------------------------------------------------

-- Send immediately when joining
sendStats()

while env.MadCityStatsLoopRunning do

    task.wait(SEND_INTERVAL)

    local success, err = pcall(sendStats)

    if not success then
        warn("[MadCity Stats] Loop error:", err)
    end

end
