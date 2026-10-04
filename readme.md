# Project Overview

This repositories contains the source for MCP server(s?) intended to augment AI tooling use for creating resources / scripts for MTA San Andreas.

## MCPs and tools
These are the tools that the MCP server exposes:

## Wiki MCP
- `GetFunctionList(side)`  
   lists MTA scripting functions grouped by category (`Server`, `Client`, `Shared`).
- `GetFunctionInformation(functionName)`  
   returns description, syntax, parameters and example for a wiki function.
- `GetEventList(side)`  
   lists scripting events for `Server` or `Client` sides.
- `GetEventParameters(eventName)`  
   returns parameters and source information for a specific event.
- `GetPedModels()`  
   returns bundled GTA:SA ped model IDs and names.
- `GetVehicleModels()`  
   returns bundled GTA:SA vehicle model IDs and names.
- `SearchWiki(query)`  
   searches the MTA Wiki and returns matching pages usable with the other tools.
- `GetPageSource(functionName)`  
   returns raw HTML source for a wiki page.

### Usage
The easiest way to use the MCP is by adding the MTA-hosted version of the MCP to your mcp.json (or your IDE's equivalent)
```json
"MTA Wiki MCP": {
	"url": "https://mcp.multitheftauto.com/wiki",
	"type": "http"
}
```

## Debug companion MCP

The Debug Companion MCP exposes tools to run Lua on a running MTA server, control resources, and fetch recent server logs.

Available tools:
- `RunCode(string code)`  
  Runs arbitrary Lua code on the server and returns the result. For multi-statement results return a value via a `return` (for example, wrap in an immediately-invoked function and `return toJSON(...)`).
- `RestartResource(string name)`  
  Restarts the specified resource.
- `StartResource(string name)`  
  Starts the specified resource.
- `StopResource(string name)`  
  Stops the specified resource.
- `GetLogs()`  
  Retrieves the latest ~100 lines of debug logs.
- `ListResources()`
  Lists available resources with their state and metadata.
- `GetResourceState(string name)`
  Gets the state of one resource.
- `RefreshResources()`
  Refreshes the MTA resource list after files change.
- `GetLogsSince(long cursor)`
  Retrieves only debug messages created after one log cursor.
- `DeployAndVerifyResource(string name)`
  Starts or restarts one resource, confirms its final state, and returns new debug logs.
- `RunResourceTests(string name)`
  Runs the optional `runDebugTests` export of a resource.

### Usage

- Run the `debugCompanion` resource on the MTA server.
- Create `Resources/debugCompanion/config.private.json` from the example and set a long random `apiKey`. This file is intentionally ignored by Git and is not downloaded by clients.
- Create a dedicated MTA account and ACL that grants only `resource.debugCompanion.http`; do not grant the MCP account admin or wildcard permissions.
- Set `serverHost`, `apiKey`, `serverUsername`, and `serverPassword` in `MtaDebugCompanionMcp.Http/appsettings.local.json`. Keep this file outside version control.
- Run the MCP locally (the HTTP MCP exposes the service on the local host).
- Add the MCP to your `mcp.json` (or IDE equivalent) pointing at the local URL (default local port used by the HTTP host is 5277):

```json
"Mta Debug Companion MCP": {
   "url": "http://localhost:5277",
   "type": "http"
}
```

Once added you can invoke the Debug Companion tools from your agent to run code, manage resources, and fetch logs.  

You can use this to let the agent iterate independently, changing code, applying it, and verifying the changes work as intended.  
It is recommended to set up a `.github/copilot-instructions.md` file in your workspace, or whatever is the equivalent for the tool you use, in order to make sure the models know how to use the MCPs.

## Development
The MCP server is a C# dotnet 10 application, developing requires dotnet 10 installed, and can be done in Visual Studio, vscore, or any IDE of your choosing.  

The codebase has several projects:
- MtaWikiMcp.Common  
  The common library which contains the actual tools that are exposed via the MCP server.
- MtaWikiMcp.Http  
  A version of the MCP server that runs via HTTP.
- MtaWikiMcp.Stdio  
  A version of the MCP server that can be executed locally via stdio if you don't want to use HTTP. Do note this will still require access to the wiki.
