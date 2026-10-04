using Microsoft.Extensions.DependencyInjection;
using MtaDebugCompanionMcp.Common.Clients;
using System.Net.Http.Headers;
using System.Text;

namespace MtaDebugCompanionMcp.Common;

public static class MtaDebugCompanionMcpServiceCollectionExtensions
{
    extension(IServiceCollection services)
    {
        /// <summary>
        /// Adds the services required for the MTA debug companion MCP.
        /// </summary>
        /// <returns></returns>
        public IServiceCollection AddMtaDebugCompanionMcpServices(string? baseAddress, string? apiKey, string? username, string? password)
        {
            services.AddHttpClient<MtaServerDebugClient>(x =>
            {
                x.BaseAddress = new Uri(baseAddress ?? "http://localhost:22005");
                x.DefaultRequestHeaders.Add("api-key", apiKey ?? "default");
                x.Timeout = TimeSpan.FromSeconds(10);

                if (!string.IsNullOrWhiteSpace(username) && !string.IsNullOrWhiteSpace(password))
                {
                    var credentials = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{username}:{password}"));
                    x.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", credentials);
                }
            });

            return services;
        }
    }
}
