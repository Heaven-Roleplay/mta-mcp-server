local CLIENT_DEBUG_EVENT = "debugCompanion:clientDebug"
local REPORT_WINDOW_MS = 10000
local MAX_REPORTS_PER_WINDOW = 30
local windowStartedAt = 0
local reportsInWindow = 0

addEventHandler("onClientDebugMessage", root, function(message, level, file, line, red, green, blue)
    if level ~= 1 and level ~= 2 then
        return
    end

    local now = getTickCount()
    if now - windowStartedAt >= REPORT_WINDOW_MS then
        windowStartedAt = now
        reportsInWindow = 0
    end
    if reportsInWindow >= MAX_REPORTS_PER_WINDOW then
        return
    end

    reportsInWindow = reportsInWindow + 1
    triggerServerEvent(CLIENT_DEBUG_EVENT, resourceRoot, message, level, file, line, red, green, blue)
end)
