local function getTargetResource(name)
    if type(name) ~= "string" or name == "" then
        return false, "Nome do resource inválido."
    end

    local resource = getResourceFromName(name)
    if not resource then
        return false, "Resource não encontrado."
    end

    return resource
end

local function getResult(result, message)
    return toJSON({ result = result == true, message = message })
end

local function isTrue(value)
    return value == true or value == "true" or value == "1"
end

-- async: responde na hora e executa em seguida. Reiniciar resources grandes (ex.: heaven_loader) trava o servidor por
-- ~30 s, mais que o tempo limite do MCP; o chamador acompanha depois pelo estado do resource.
local function runAction(action, resource, async)
    if isTrue(async) then
        setTimer(action, 50, 1, resource)
        return getResult(true, "agendado")
    end
    return getResult(action(resource))
end

function httpStartResource(name, async)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resource, errorMessage = getTargetResource(name)
    if not resource then return getResult(false, errorMessage) end

    return runAction(startResource, resource, async)
end

function httpRestartResource(name, async)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resource, errorMessage = getTargetResource(name)
    if not resource then return getResult(false, errorMessage) end

    return runAction(restartResource, resource, async)
end

function httpStopResource(name)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resource, errorMessage = getTargetResource(name)
    if not resource then return getResult(false, errorMessage) end

    return getResult(stopResource(resource))
end

-- Sem filtro: contagem por estado e os nomes só dos estados fora do normal (failed to load, starting...); use state=loaded para ver os parados.
-- Com state e/ou contains: os nomes dos que casam. Uma linha por estado, nomes separados por espaço.
function httpListResources(state, contains)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local wantedState = type(state) == "string" and state ~= "" and state or false
    local text = type(contains) == "string" and contains ~= "" and contains:lower() or false
    local counts, names, order = {}, {}, {}
    local resources = getResources()
    for index = 1, #resources do
        local resource = resources[index]
        local resourceState = getResourceState(resource)
        local name = getResourceName(resource)
        counts[resourceState] = (counts[resourceState] or 0) + 1
        local listed = wantedState or text or (resourceState ~= "running" and resourceState ~= "stopped" and resourceState ~= "loaded")
        if listed and (not wantedState or resourceState == wantedState) and (not text or name:lower():find(text, 1, true)) then
            if not names[resourceState] then
                names[resourceState] = {}
                order[#order + 1] = resourceState
            end
            names[resourceState][#names[resourceState] + 1] = name
        end
    end

    local summary = {}
    for resourceState, count in pairs(counts) do
        summary[#summary + 1] = resourceState .. "=" .. count
    end
    table.sort(summary)
    local lines = {"total=" .. #resources .. " " .. table.concat(summary, " ")}
    table.sort(order)
    for index = 1, #order do
        local list = names[order[index]]
        table.sort(list)
        lines[#lines + 1] = order[index] .. " (" .. #list .. "): " .. table.concat(list, " ")
    end
    return table.concat(lines, "\n")
end

function httpGetResourceState(name)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resource, errorMessage = getTargetResource(name)
    if not resource then return getResult(false, errorMessage) end

    return toJSON({ result = true, state = getResourceState(resource) })
end

function httpRefreshResources()
    if not verifyApiKey() then
        return "Unauthorised"
    end

    return getResult(refreshResources())
end
