using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Net.Http;
using System.Threading.Tasks;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();

var app = builder.Build();

app.MapGet("/", () => ".NET application is running!");

app.MapGet("/call-target", async (HttpContext context, IHttpClientFactory httpClientFactory) =>
{
    if (new Random().NextDouble() < 0.4)
    {
        context.Response.StatusCode = 500;
        await context.Response.WriteAsync("{\"error\": \"An unexpected error occurred\"}");
        return;
    }

    var targetUrl = Environment.GetEnvironmentVariable("TARGET_URL");
    if (string.IsNullOrEmpty(targetUrl))
    {
        context.Response.StatusCode = 500;
        await context.Response.WriteAsync("{\"error\": \"TARGET_URL environment variable not set\"}");
        return;
    }

    try
    {
        var client = httpClientFactory.CreateClient();
        var response = await client.GetAsync(targetUrl);
        var responseText = await response.Content.ReadAsStringAsync();
        context.Response.StatusCode = (int)response.StatusCode;
        await context.Response.WriteAsync(responseText);
    }
    catch (Exception ex)
    {
        context.Response.StatusCode = 500;
        await context.Response.WriteAsync($"{{\"error\": \"Failed to reach {targetUrl}: {ex.Message}\"}}");
    }
});

app.Run();