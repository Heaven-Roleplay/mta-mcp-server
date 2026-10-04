using ModelContextProtocol.Server;
using MtaDebugCompanionMcp.Common.Clients;
using System.ComponentModel;

namespace MtaDebugCompanionMcp.Common.Tools;

[McpServerToolType]
[Description("Ações no servidor MTA (resources, logs, Lua). Respostas curtas em texto.")]
public class MtaDebugCompanionTools(MtaServerDebugClient mtaServer)
{
    private const string LogHelp = "limit: quantos registros (padrão 30, máx 200, vêm os mais recentes). level: 1 só erros, 2 +avisos, 3 +info, 4 tudo (padrão). contains: texto na mensagem ou no arquivo. side: server ou client. includeNoise: inclui o ruído filtrado por padrão (hook do heaven_monitor).";

    [McpServerTool(Name = nameof(RunCode))]
    [Description("Executa Lua no servidor. Para vários comandos: (function() ... return toJSON({...}) end)()")]
    public Task<string> RunCode(string code) => mtaServer.RunCode(code);

    [McpServerTool(Name = nameof(RestartResource))]
    [Description("Reinicia um resource. Devolve ok ou erro.")]
    public Task<string> RestartResource(string name) => mtaServer.RestartResource(name);

    [McpServerTool(Name = nameof(StartResource))]
    [Description("Inicia um resource. Devolve ok ou erro.")]
    public Task<string> StartResource(string name) => mtaServer.StartResource(name);

    [McpServerTool(Name = nameof(StopResource))]
    [Description("Para um resource. Devolve ok ou erro.")]
    public Task<string> StopResource(string name) => mtaServer.StopResource(name);

    [McpServerTool(Name = nameof(GetResourceState))]
    [Description("Estado de um resource (running, loaded, stopped...).")]
    public Task<string> GetResourceState(string name) => mtaServer.GetResourceState(name);

    [McpServerTool(Name = nameof(ListResources))]
    [Description("Sem filtro: contagem por estado e os nomes só dos fora do normal (failed to load); state=loaded lista os parados. Com state e/ou contains: os nomes que casam.")]
    public Task<string> ListResources(string? state = null, string? contains = null) => mtaServer.ListResources(state, contains);

    [McpServerTool(Name = nameof(RefreshResources))]
    [Description("Atualiza a lista de resources (depois de criar, remover ou renomear arquivos).")]
    public Task<string> RefreshResources() => mtaServer.RefreshResources();

    [McpServerTool(Name = nameof(GetLogs))]
    [Description("Últimos registros do debug, uma linha cada: nível lado hora mensagem (arquivo:linha). Repetições seguidas viram xN. " + LogHelp)]
    public Task<string> GetLogs(int limit = 30, int level = 4, string? contains = null, string? side = null, bool includeNoise = false) =>
        mtaServer.GetLogs(limit, level, contains, side, includeNoise);

    [McpServerTool(Name = nameof(GetLogCursor))]
    [Description("Só o marcador atual dos logs. Use antes de pedir um teste e depois leia com GetLogsSince.")]
    public Task<string> GetLogCursor() => mtaServer.GetLogCursor();

    [McpServerTool(Name = nameof(GetLogsSince))]
    [Description("Registros depois de um marcador; o cabeçalho traz o marcador novo. " + LogHelp)]
    public Task<string> GetLogsSince(long cursor, int limit = 30, int level = 4, string? contains = null, string? side = null, bool includeNoise = false) =>
        mtaServer.GetLogsSince(cursor, limit, level, contains, side, includeNoise);

    [McpServerTool(Name = nameof(DeployAndVerifyResource))]
    [Description("Inicia ou reinicia um resource, espera subir e devolve uma linha de resumo mais os registros novos que citam o resource (e qualquer erro). Aguenta resources lentos como o heaven_loader.")]
    public Task<string> DeployAndVerifyResource(string name, int limit = 20) => mtaServer.DeployAndVerifyResource(name, limit);

    [McpServerTool(Name = nameof(RunResourceTests))]
    [Description("Roda o export runDebugTests de um resource em execução.")]
    public Task<string> RunResourceTests(string name) => mtaServer.RunResourceTests(name);
}
