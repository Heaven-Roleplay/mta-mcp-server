using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace MtaDebugCompanionMcp.Common.Clients;

/// <summary>
/// Fala com o resource debugCompanion do servidor MTA. As respostas voltam em texto curto (uma linha por registro)
/// para gastar pouco contexto de quem usa o MCP; o JSON embrulhado pelo MTA ([ "..." ]) é desembrulhado aqui.
/// </summary>
public class MtaServerDebugClient(HttpClient httpClient)
{
    private const int DeployTimeoutSeconds = 90;
    private const int DeploySettleMs = 1200;

    private static StringContent ToJsonContent<T>(T value) =>
        new(JsonSerializer.Serialize(value), Encoding.UTF8, "application/json");

    private async Task<string> Post(string path, params string?[] values)
    {
        var response = await httpClient.PostAsync(path, ToJsonContent(values.Select(value => value ?? "").ToArray()));
        return await response.Content.ReadAsStringAsync();
    }

    /// <summary>Texto que o Lua devolveu, sem o array JSON que o MTA põe em volta.</summary>
    private static string Unwrap(string response)
    {
        try
        {
            using var document = JsonDocument.Parse(response);
            if (document.RootElement.ValueKind == JsonValueKind.Array && document.RootElement.GetArrayLength() > 0)
            {
                var first = document.RootElement[0];
                return first.ValueKind == JsonValueKind.String ? first.GetString() ?? "" : first.GetRawText();
            }
        }
        catch (JsonException)
        {
        }

        return response;
    }

    /// <summary>Objeto {result, message, state...} que o Lua devolveu com toJSON (o MTA o embrulha em array).</summary>
    private static JsonNode? ReadObject(string response)
    {
        try
        {
            var node = JsonNode.Parse(Unwrap(response));
            return node is JsonArray array && array.Count > 0 ? array[0] : node;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    private static string ActionText(string response)
    {
        var node = ReadObject(response);
        if (node is null)
        {
            return Unwrap(response);
        }

        var ok = node["result"]?.GetValue<bool>() == true;
        var message = node["message"]?.GetValue<string>();
        return ok ? (message is null ? "ok" : "ok (" + message + ")") : "erro: " + (message ?? "a ação não foi executada");
    }

    private static string StateOf(string response) => ReadObject(response)?["state"]?.GetValue<string>() ?? "desconhecido";

    public async Task<string> RunCode(string code) => Unwrap(await Post("/debugCompanion/call/httpRun", code));

    public async Task<string> RestartResource(string name) => ActionText(await Post("/debugCompanion/call/httpRestartResource", name));

    public async Task<string> StartResource(string name) => ActionText(await Post("/debugCompanion/call/httpStartResource", name));

    public async Task<string> StopResource(string name) => ActionText(await Post("/debugCompanion/call/httpStopResource", name));

    public async Task<string> RefreshResources() => ActionText(await Post("/debugCompanion/call/httpRefreshResources"));

    public async Task<string> GetResourceState(string name)
    {
        var response = await Post("/debugCompanion/call/httpGetResourceState", name);
        var state = StateOf(response);
        return state == "desconhecido" ? ActionText(response) : state;
    }

    public async Task<string> ListResources(string? state, string? contains) =>
        Unwrap(await Post("/debugCompanion/call/httpListResources", state, contains));

    public async Task<string> GetLogs(int limit, int level, string? contains, string? side, bool includeNoise) =>
        Unwrap(await Post("/debugCompanion/call/httpGetDebugLog", limit.ToString(), level.ToString(), contains, side, includeNoise ? "1" : "0"));

    public async Task<string> GetLogsSince(long cursor, int limit, int level, string? contains, string? side, bool includeNoise) =>
        Unwrap(await Post("/debugCompanion/call/httpGetDebugLogSince", cursor.ToString(), limit.ToString(), level.ToString(), contains, side, includeNoise ? "1" : "0"));

    public async Task<string> GetLogCursor() => Unwrap(await Post("/debugCompanion/call/httpGetDebugLogCursor"));

    public async Task<string> RunResourceTests(string name) => Unwrap(await Post("/debugCompanion/call/httpRunResourceTests", name));

    /// <summary>
    /// Inicia ou reinicia o resource, espera ele ficar de pé e devolve só o que importa:
    /// uma linha de resumo e os registros novos que citam o resource (mais qualquer erro).
    /// </summary>
    public async Task<string> DeployAndVerifyResource(string name, int limit)
    {
        var initialState = StateOf(await Post("/debugCompanion/call/httpGetResourceState", name));
        if (initialState == "desconhecido")
        {
            return "erro: resource não encontrado: " + name;
        }

        long.TryParse(await GetLogCursor(), out var cursor);
        var action = initialState == "running" ? "restart" : "start";
        var timer = Stopwatch.StartNew();

        // Assíncrono: reiniciar o heaven_loader trava o servidor por ~30 s, mais que o tempo de uma chamada comum.
        var path = action == "restart" ? "/debugCompanion/call/httpRestartResource" : "/debugCompanion/call/httpStartResource";
        var scheduled = ActionText(await Post(path, name, "1"));
        if (!scheduled.StartsWith("ok"))
        {
            return $"{name}: {action} {scheduled}";
        }

        // O timer do servidor dispara em ~50 ms; só depois disso o estado deixa de ser o antigo.
        await Task.Delay(700);
        var state = StateOf(await Post("/debugCompanion/call/httpGetResourceState", name));
        while (state != "running" && timer.Elapsed.TotalSeconds < DeployTimeoutSeconds)
        {
            await Task.Delay(500);
            state = StateOf(await Post("/debugCompanion/call/httpGetResourceState", name));
        }

        await Task.Delay(DeploySettleMs);
        var logs = Unwrap(await Post("/debugCompanion/call/httpGetDebugLogSince", cursor.ToString(), limit.ToString(), "4", "", "", "0", name));
        var (errors, warnings) = CountProblems(logs);

        var status = state == "running" ? "running" : "NÃO SUBIU (estado: " + state + ")";
        return $"{name}: {action} -> {status} em {timer.Elapsed.TotalSeconds:0.0}s | erros={errors} avisos={warnings}\n{logs}";
    }

    private static (int errors, int warnings) CountProblems(string logs)
    {
        int errors = 0, warnings = 0;
        foreach (var line in logs.Split('\n').Skip(1))
        {
            if (line.StartsWith("1 "))
            {
                errors++;
            }
            else if (line.StartsWith("2 "))
            {
                warnings++;
            }
        }

        return (errors, warnings);
    }
}
