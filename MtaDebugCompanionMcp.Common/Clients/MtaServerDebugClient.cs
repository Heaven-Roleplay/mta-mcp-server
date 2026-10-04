using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace MtaDebugCompanionMcp.Common.Clients;

public class MtaServerDebugClient(HttpClient httpClient)
{
    private static StringContent ToJsonContent<T>(T value) =>
        new(JsonSerializer.Serialize(value), Encoding.UTF8, "application/json");

    private async Task<string> Post(string path, params string[] values)
    {
        var response = await httpClient.PostAsync(path, ToJsonContent(values));
        return await response.Content.ReadAsStringAsync();
    }

    public async Task<string> RunCode(string code)
    {
        return await Post("/debugCompanion/call/httpRun", code);
    }

    public async Task<string> RestartResource(string name)
    {
        return await Post("/debugCompanion/call/httpRestartResource", name);
    }

    public async Task<string> StartResource(string name)
    {
        return await Post("/debugCompanion/call/httpStartResource", name);
    }

    public async Task<string> StopResource(string name)
    {
        return await Post("/debugCompanion/call/httpStopResource", name);
    }

    public async Task<string> GetLogs()
    {
        return await Post("/debugCompanion/call/httpGetDebugLog");
    }

    public Task<string> ListResources() => Post("/debugCompanion/call/httpListResources");

    public Task<string> GetResourceState(string name) => Post("/debugCompanion/call/httpGetResourceState", name);

    public Task<string> RefreshResources() => Post("/debugCompanion/call/httpRefreshResources");

    public Task<string> GetLogsSince(long cursor) => Post("/debugCompanion/call/httpGetDebugLogSince", cursor.ToString());

    public Task<string> RunResourceTests(string name) => Post("/debugCompanion/call/httpRunResourceTests", name);

    public async Task<string> DeployAndVerifyResource(string name)
    {
        var initialLogs = ReadMtaValue(await GetLogsSince(0));
        var cursor = initialLogs?["cursor"]?.GetValue<long>() ?? 0;
        var initialState = ReadResourceState(await GetResourceState(name));
        var action = initialState == "running" ? "restart" : "start";
        var actionResult = action == "restart"
            ? await RestartResource(name)
            : await StartResource(name);

        await Task.Delay(300);

        var finalState = ReadResourceState(await GetResourceState(name));
        var logs = ReadMtaValue(await GetLogsSince(cursor));

        return new JsonObject
        {
            ["name"] = name,
            ["action"] = action,
            ["result"] = ReadMtaValue(actionResult),
            ["state"] = finalState,
            ["logs"] = logs,
            ["hasErrors"] = HasErrors(logs),
        }.ToJsonString();
    }

    private static JsonNode? ReadMtaValue(string response)
    {
        try
        {
            using var document = JsonDocument.Parse(response);
            if (document.RootElement.ValueKind != JsonValueKind.Array || document.RootElement.GetArrayLength() == 0)
            {
                return JsonValue.Create(response);
            }

            var value = document.RootElement[0];
            if (value.ValueKind != JsonValueKind.String)
            {
                return ReadValue(JsonNode.Parse(value.GetRawText()));
            }

            var content = value.GetString() ?? "";
            try
            {
                return ReadValue(JsonNode.Parse(content));
            }
            catch (JsonException)
            {
                return JsonValue.Create(content);
            }
        }
        catch (JsonException)
        {
            return JsonValue.Create(response);
        }
    }

    private static JsonNode? ReadValue(JsonNode? value)
    {
        if (value is JsonArray array && array.Count > 0)
        {
            return array[0]?.DeepClone();
        }

        return value;
    }

    private static string ReadResourceState(string response)
    {
        return ReadMtaValue(response)?["state"]?.GetValue<string>() ?? "unknown";
    }

    private static bool HasErrors(JsonNode? logs)
    {
        var entries = logs?["entries"]?.AsArray();
        if (entries is null)
        {
            return false;
        }

        for (var index = 0; index < entries.Count; index++)
        {
            if (entries[index]?["level"]?.GetValue<int>() == 1)
            {
                return true;
            }
        }

        return false;
    }
}
