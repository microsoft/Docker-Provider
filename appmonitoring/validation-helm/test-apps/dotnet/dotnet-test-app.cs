using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using System.Diagnostics.Metrics;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddHttpClient();
builder.Services.AddControllers();

var meter = new Meter("dotnet-test-app", "1.0.0");
var cowsSoldCounter = meter.CreateCounter<long>("cows_sold_total", description: "Total number of cows sold");
var cowsSoldHistogram = meter.CreateHistogram<double>("cows_sold_total_histogram", description: "Request duration for cow sales in milliseconds");

Console.WriteLine("=========================================");
Console.WriteLine($"Created Meter: {meter.Name} (Version: {meter.Version})");
Console.WriteLine($"Created Counter: cows_sold_total");
Console.WriteLine($"Created Histogram: cows_sold_total_histogram");
Console.WriteLine($"OTEL_DOTNET_AUTO_METRICS_ADDITIONAL_SOURCES: {Environment.GetEnvironmentVariable("OTEL_DOTNET_AUTO_METRICS_ADDITIONAL_SOURCES")}");
Console.WriteLine($"OTEL_METRICS_EXPORTER: {Environment.GetEnvironmentVariable("OTEL_METRICS_EXPORTER")}");
Console.WriteLine($"OTEL_EXPORTER_OTLP_METRICS_ENDPOINT: {Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")}");
Console.WriteLine("=========================================");

// Register them as singletons so they can be injected
builder.Services.AddSingleton(meter);
builder.Services.AddSingleton(cowsSoldCounter);
builder.Services.AddSingleton(cowsSoldHistogram);

var app = builder.Build();

app.MapControllers();

app.Run();

[ApiController]
[Route("/")]
public class HomeController : ControllerBase
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<HomeController> _logger;
    private readonly Counter<long> _cowsSoldCounter;
    private readonly Histogram<double> _cowsSoldHistogram;
    
    public HomeController(IHttpClientFactory httpClientFactory, ILogger<HomeController> logger, Counter<long> cowsSoldCounter, Histogram<double> cowsSoldHistogram)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
        _cowsSoldCounter = cowsSoldCounter;
        _cowsSoldHistogram = cowsSoldHistogram;
    }

    [HttpGet]
    public IActionResult Get()
    {
        return Ok(".NET application is running!");
    }

    [HttpGet("call-target")]
    public async Task<IActionResult> CallTarget()
    {
        var stopwatch = Stopwatch.StartNew();
        
        // Increment the cows sold counter
        _cowsSoldCounter.Add(1, new KeyValuePair<string, object?>[]
            {
                new("cow_type", "Holstein .NET"),
                new("endpoint", Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")),
                new("protocol", Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_PROTOCOL"))
            });
        
        stopwatch.Stop();
        _cowsSoldHistogram.Record(stopwatch.ElapsedMilliseconds, new KeyValuePair<string, object?>[]
            {
                new("cow_type", "Holstein .NET")
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