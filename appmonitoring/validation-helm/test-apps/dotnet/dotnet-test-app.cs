using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using System.Diagnostics.Metrics;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();
builder.Services.AddControllers();

var app = builder.Build();

app.MapControllers();

app.Run();

[ApiController]
[Route("/")]
public class HomeController : ControllerBase
{
    private static readonly Meter meter = new Meter("dotnet-test-app", "1.0.0");
    private readonly Counter<long> _cowsSoldCounter = meter.CreateCounter<long>("cows_sold_total", description: "Total number of cows sold");

    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<HomeController> _logger;
    
    public HomeController(IHttpClientFactory httpClientFactory, ILogger<HomeController> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Get()
    {
        return Ok(".NET application is running!");
    }

    [HttpGet("call-target")]
    public async Task<IActionResult> CallTarget()
    {
        // Increment the cows sold counter
        _cowsSoldCounter.Add(1, new KeyValuePair<string, object?>[]
            {
                new("cow_type", "Holstein .NET"),
                new("endpoint", Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")),
                new("protocol", Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_PROTOCOL"))
            });
        
        if (new Random().NextDouble() < 0.4)
        {
            throw new Exception("An unexpected error occurred");
        }

        var targetUrl = Environment.GetEnvironmentVariable("TARGET_URL");
        if (string.IsNullOrEmpty(targetUrl))
        {
            return StatusCode(500, new { error = "TARGET_URL environment variable not set" });
        }

        try
        {
            var client = _httpClientFactory.CreateClient();
            var response = await client.GetAsync(targetUrl);
            var responseText = await response.Content.ReadAsStringAsync();
            return StatusCode((int)response.StatusCode, responseText);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = $"Failed to reach {targetUrl}" });
        }
    }
}