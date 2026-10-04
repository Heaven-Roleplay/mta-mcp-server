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

local function hasDebugTests(resource)
    local functions = getResourceExportedFunctions(resource)
    if type(functions) ~= "table" then
        return false
    end

    for index = 1, #functions do
        if functions[index] == "runDebugTests" then
            return true
        end
    end

    return false
end

function httpRunResourceTests(name)
    if not verifyApiKey() then
        return "Unauthorised"
    end

    local resource, errorMessage = getTargetResource(name)
    if not resource then
        return toJSON({ result = false, available = false, message = errorMessage })
    end

    if getResourceState(resource) ~= "running" then
        return toJSON({ result = false, available = false, message = "Resource não está em execução." })
    end

    if not hasDebugTests(resource) then
        return toJSON({ result = true, available = false, message = "Resource não possui runDebugTests." })
    end

    local tests = call(resource, "runDebugTests")
    if type(tests) ~= "table" then
        return toJSON({ result = false, available = true, message = "runDebugTests retornou um formato inválido." })
    end

    local result = {
        result = true,
        available = true,
        tests = {},
    }

    for index = 1, #tests do
        local test = tests[index]
        if type(test) ~= "table" or type(test.name) ~= "string" or type(test.success) ~= "boolean" then
            return toJSON({ result = false, available = true, message = "runDebugTests retornou um caso de teste inválido." })
        end

        result.tests[#result.tests + 1] = {
            name = test.name,
            success = test.success,
            message = type(test.message) == "string" and test.message or "",
        }

        if not test.success then
            result.result = false
        end
    end

    return toJSON(result)
end

function runDebugTests()
    return {
        {
            name = "Companion iniciado",
            success = true,
            message = "Endpoints de depuração carregados.",
        },
    }
end
