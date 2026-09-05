--// Mad City Chapter 1 Cash Gain Logger
--// Sends when you earn 10k+ Cash

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local env = getgenv()
local Player = Players.LocalPlayer

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local WEBHOOK = env.MadCityWebhook
local MIN_GAIN = tonumber(env.MadCityMinGain) or 10000

if not WEBHOOK or WEBHOOK == "" then
    error("[MadCity Stats] MadCityWebhook is missing.")
end

--------------------------------------------------
-- REMOVE OLD LISTENER IF SCRIPT IS RE-EXECUTED
--------------------------------------------------

if env.MadCityCashConnection then
    pcall(function()
        env.MadCityCashConnection:Disconnect()
    end)

    env.MadCityCashConnection = nil
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
    error("[MadCity Stats] No HTTP request function found.")
end

--------------------------------------------------
-- WAIT FOR STATS
--------------------------------------------------

local leaderstats = Player:WaitForChild("leaderstats", 60)

if not leaderstats then
    error("[MadCity Stats] leaderstats not found.")
end

local Cash = leaderstats:WaitForChild("Cash", 30)
local Rank = leaderstats:WaitForChild("Rank", 30)

if not Cash then
    error("[MadCity Stats] Cash not found.")
end

if not Rank then
    error("[MadCity Stats] Rank not found.")
end

--------------------------------------------------
-- FORMAT NUMBER
--------------------------------------------------

local function formatNumber(number)
    local str = tostring(math.floor(tonumber(number) or 0))

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
-- SEND WEBHOOK
--------------------------------------------------

local function sendWebhook(gained, currentCash)

    local payload = {
        username = "Mad City Stats",

        embeds = {
            {
                title = "💰 Cash Milestone",

                description =
                    "**" .. Player.DisplayName .. "** " ..
                    "(@" .. Player.Name .. ") earned enough cash.",

                color = 0x57F287,

                fields = {
                    {
                        name = "💵 Cash Gained",
                        value = "+$" .. formatNumber(gained),
                        inline = true
                    },

                    {
                        name = "💰 Current Cash",
                        value = "$" .. formatNumber(currentCash),
                        inline = true
                    },

                    {
                        name = "⭐ Rank",
                        value = tostring(Rank.Value),
                        inline = true
                    }
                },

                footer = {
                    text =
                        "Notification threshold: $" ..
                        formatNumber(MIN_GAIN)
                },

                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }

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

            Body = HttpService:JSONEncode(payload)
        })
    end)

    if not success then
        warn("[MadCity Stats] Webhook failed:", response)
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
        "[MadCity Stats] Webhook sent | Gain:",
        gained,
        "| Cash:",
        currentCash,
        "| HTTP:",
        status or "unknown"
    )
end

--------------------------------------------------
-- CASH TRACKING
--------------------------------------------------

local lastCash = tonumber(Cash.Value) or 0
local gainedSinceLastSend = 0

print("[MadCity Stats] Cash watcher started.")
print("[MadCity Stats] Starting Cash:", lastCash)
print("[MadCity Stats] Notify every +$" .. formatNumber(MIN_GAIN))

env.MadCityCashConnection = Cash:GetPropertyChangedSignal("Value"):Connect(function()

    local currentCash = tonumber(Cash.Value)

    if not currentCash then
        return
    end

    local difference = currentCash - lastCash

    -- Only count money gained.
    -- Spending money won't reduce progress.
    if difference > 0 then

        gainedSinceLastSend += difference

        print(
            "[MadCity Stats] +$" .. formatNumber(difference),
            "| Progress: $" ..
            formatNumber(gainedSinceLastSend) ..
            "/" ..
            formatNumber(MIN_GAIN)
        )

        if gainedSinceLastSend >= MIN_GAIN then

            local gained = gainedSinceLastSend

            -- Reset after notification
            gainedSinceLastSend = 0

            task.spawn(function()
                sendWebhook(gained, currentCash)
            end)

        end
    end

    lastCash = currentCash
end)

print("[MadCity Stats] Running in background.")
