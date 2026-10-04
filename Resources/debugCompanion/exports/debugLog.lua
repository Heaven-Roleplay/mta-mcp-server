local debugLogCache = {}
local MAX_DEBUG_LOG = 500
local debugLogCursor = 0
local CLIENT_DEBUG_EVENT = "debugCompanion:clientDebug"
local REPORT_WINDOW_MS = 10000
local MAX_REPORTS_PER_WINDOW = 30
local MAX_MESSAGE_LENGTH = 2048
local MAX_FILE_LENGTH = 300
local clientWindows = {}

local function clampColor(value)
	local number = tonumber(value)
	if not number or number ~= number then
		return 255
	end
	return math.max(0, math.min(255, math.floor(number)))
end

local function isAccountLoggedIn(player)
	local accounts = getResourceFromName("heaven_accounts")
	if not accounts or getResourceState(accounts) ~= "running" then
		return false
	end
	local success, loggedIn = pcall(function()
		return exports.heaven_accounts:isPlayerLoggedIn(player)
	end)
	return success and loggedIn == true
end

local function addToDebugCache(entry)
	debugLogCursor = debugLogCursor + 1
	entry.id = debugLogCursor
	table.insert(debugLogCache, entry)
	if #debugLogCache > MAX_DEBUG_LOG then
		table.remove(debugLogCache, 1)
	end
end

-- Ruído que não ajuda a depurar resources (o heaven_monitor tenta o debug hook sem permissão a cada captura).
local NOISE = {"Access denied @ 'addDebugHook'", "Access denied @ 'removeDebugHook'", "[heaven_monitor]"}
local DEFAULT_LIMIT = 30
local MAX_LIMIT = 200
local MAX_LINE_LENGTH = 300

local function isNoise(entry)
	for index = 1, #NOISE do
		if entry.message:find(NOISE[index], 1, true) then
			return true
		end
	end
	return false
end

local function mentions(entry, text)
	return entry.message:lower():find(text, 1, true) ~= nil or (entry.file and tostring(entry.file):lower():find(text, 1, true) ~= nil)
end

-- Últimos dois trechos do caminho ("client/interactions.lua"); o resource já aparece no prefixo da mensagem.
local function shortFile(file)
	local parts = {}
	for part in tostring(file):gmatch("[^/\\]+") do
		parts[#parts + 1] = part
	end
	local count = #parts
	return count > 1 and (parts[count - 1] .. "/" .. parts[count]) or (parts[count] or "")
end

local function formatEntry(entry, repeats)
	local who = entry.side == "client" and ("c:" .. tostring(entry.player or "?")) or "s"
	local where = entry.file and (" (" .. shortFile(entry.file) .. (entry.line and (":" .. entry.line) or "") .. ")") or ""
	local message = entry.message:gsub("[\r\n]+", " "):sub(1, MAX_LINE_LENGTH)
	return string.format("%d %s %s %s%s%s", entry.level, who, os.date("%H:%M:%S", entry.time), message, repeats > 1 and (" x" .. repeats) or "", where)
end

-- opts: limit, level (1 erro, 2 aviso, 3 info, 4 tudo), contains, side, focus (resource: erros de qualquer lugar + tudo que cita o resource), noise (true mantém o ruído)
-- Devolve texto compacto: uma linha de cabeçalho com o cursor novo e uma linha por registro (repetições seguidas viram "xN").
local function buildLogText(cursor, opts)
	local limit = math.min(MAX_LIMIT, math.max(1, tonumber(opts.limit) or DEFAULT_LIMIT))
	local maxLevel = tonumber(opts.level) or 4
	local contains = opts.contains and opts.contains:lower() or false
	local focus = opts.focus and opts.focus:lower() or false

	local lines, rows = {}, {}
	for index = 1, #debugLogCache do
		local entry = debugLogCache[index]
		local level = entry.level == 0 and 3 or entry.level
		if entry.id > cursor and level <= maxLevel
			and (not opts.side or entry.side == opts.side)
			and (not contains or mentions(entry, contains))
			and (not focus or level == 1 or mentions(entry, focus))
			and (opts.noise or not isNoise(entry)) then
			local previous = rows[#rows]
			if previous and previous.entry.message == entry.message and previous.entry.level == entry.level and previous.entry.side == entry.side and previous.entry.player == entry.player then
				previous.repeats = previous.repeats + 1
			else
				rows[#rows + 1] = {entry = entry, repeats = 1}
			end
		end
	end

	local first = math.max(1, #rows - limit + 1)
	for index = first, #rows do
		lines[#lines + 1] = formatEntry(rows[index].entry, rows[index].repeats)
	end
	local header = "cursor=" .. debugLogCursor .. " mostrando=" .. #lines
	if first > 1 then
		header = header .. " omitidas_antigas=" .. (first - 1)
	end
	return header .. (#lines > 0 and ("\n" .. table.concat(lines, "\n")) or "")
end

local function onDebugMessageHandler(debugMessage, debugLevel, debugFile, debugLine, debugRed, debugGreen, debugBlue)
	local entry = {
		side = "server",
		message = tostring(debugMessage):sub(1, MAX_MESSAGE_LENGTH),
		level = tonumber(debugLevel) or 0,
		file = debugFile or false,
		line = debugLine or false,
		color = { debugRed or 255, debugGreen or 255, debugBlue or 255 },
		time = os.time()
	}

	addToDebugCache(entry)

	return false
end

addEventHandler("onDebugMessage", root, onDebugMessageHandler)

addEvent(CLIENT_DEBUG_EVENT, true)
addEventHandler(CLIENT_DEBUG_EVENT, resourceRoot, function(message, level, file, line, red, green, blue)
	local player = client
	if not isElement(player) or getElementType(player) ~= "player" or source ~= resourceRoot then
		return
	end
	if type(message) ~= "string" or (level ~= 1 and level ~= 2) then
		return
	end

	local now = getTickCount()
	local window = clientWindows[player]
	if not window or now - window.startedAt >= REPORT_WINDOW_MS then
		window = {startedAt = now, count = 0}
		clientWindows[player] = window
	end
	if window.count >= MAX_REPORTS_PER_WINDOW then
		return
	end
	window.count = window.count + 1

	local fileName = type(file) == "string" and file:sub(1, MAX_FILE_LENGTH) or false
	local fileLine = tonumber(line)
	addToDebugCache({
		side = "client",
		player = getPlayerName(player),
		accountLoggedIn = isAccountLoggedIn(player),
		message = message:sub(1, MAX_MESSAGE_LENGTH),
		level = level,
		file = fileName,
		line = fileLine and fileLine == fileLine and math.max(0, math.min(1000000, math.floor(fileLine))) or false,
		color = {clampColor(red), clampColor(green), clampColor(blue)},
		time = os.time(),
	})
end)

addEventHandler("onPlayerQuit", root, function()
	clientWindows[source] = nil
end)

local function isTrue(value)
	return value == true or value == "true" or value == "1"
end

local function readOptions(limit, level, contains, side, noise, focus)
	return {
		limit = limit,
		level = level,
		contains = type(contains) == "string" and contains ~= "" and contains or false,
		side = (side == "server" or side == "client") and side or false,
		noise = isTrue(noise),
		focus = type(focus) == "string" and focus ~= "" and focus or false,
	}
end

-- Últimos registros (sem cursor); aceita os mesmos filtros do "since".
function httpGetDebugLog(limit, level, contains, side, noise)
	if not verifyApiKey() then
		return "Unauthorised"
	end
	return buildLogText(0, readOptions(limit, level, contains, side, noise))
end

function httpGetDebugLogSince(cursor, limit, level, contains, side, noise, focus)
	if not verifyApiKey() then
		return "Unauthorised"
	end
	return buildLogText(math.max(0, tonumber(cursor) or 0), readOptions(limit, level, contains, side, noise, focus))
end

-- Só o marcador atual: serve para marcar um ponto antes de testar e ler depois só o que veio depois.
function httpGetDebugLogCursor()
	if not verifyApiKey() then
		return "Unauthorised"
	end
	return tostring(debugLogCursor)
end
