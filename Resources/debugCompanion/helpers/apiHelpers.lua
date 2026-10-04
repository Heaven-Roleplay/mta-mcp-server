local apiKey = false

function verifyApiKey()
    if not apiKey or type(requestHeaders) ~= "table" then
        return false
    end

    local header = false
    for name, value in pairs(requestHeaders) do
        if string.lower(name) == "api-key" then
            header = value
            break
        end
    end

    return type(header) == "string" and header == apiKey
end

function loadApiKey()
    local file = fileOpen("config.private.json")
    if not file then
        outputServerLog("[debugCompanion] API key ausente. Configure config.private.json antes de usar o MCP.")
        return false
    end

    local content = fileRead(file, fileGetSize(file))
    fileClose(file)

    local config = fromJSON(content)
    if type(config) ~= "table" or type(config.apiKey) ~= "string" or config.apiKey == "" then
        outputServerLog("[debugCompanion] config.private.json possui uma API key inválida.")
        return false
    end

    apiKey = config.apiKey
    return true
end

loadApiKey()
