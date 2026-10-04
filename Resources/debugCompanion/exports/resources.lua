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

function httpStartResource(name)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resource, errorMessage = getTargetResource(name)
    if not resource then return getResult(false, errorMessage) end

    return getResult(startResource(resource))
end

function httpRestartResource(name)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resource, errorMessage = getTargetResource(name)
    if not resource then return getResult(false, errorMessage) end

    return getResult(restartResource(resource))
end

function httpStopResource(name)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resource, errorMessage = getTargetResource(name)
    if not resource then return getResult(false, errorMessage) end

    return getResult(stopResource(resource))
end

function httpListResources()
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resources = getResources()
    local result = {}
    for index = 1, #resources do
        local resource = resources[index]
        result[index] = {
            name = getResourceName(resource),
            state = getResourceState(resource),
            type = getResourceInfo(resource, "type") or "",
            author = getResourceInfo(resource, "author") or "",
        }
    end

    return toJSON(result)
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
