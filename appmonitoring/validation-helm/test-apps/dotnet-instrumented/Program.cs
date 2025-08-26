using Microsoft.AspNetCore.Mvc;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Exporter;
using System.Diagnostics;
using System.Diagnostics.Metrics;

var builder = WebApplication.CreateBuilder(args);

// Configure environment variables programmatically (similar to nodejs instrumentation.js)
Environment.SetEnvironmentVariable("OTEL_SERVICE_NAME", "dotnet-instrumented-test-app");
Environment.SetEnvironmentVariable("OTEL_SERVICE_VERSION", "1.0.0");
Environment.SetEnvironmentVariable("OTEL_ENVIRONMENT", "development");

// Get configurable endpoint and protocol from environment variables
var metricsEndpoint = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT") ?? "http://localhost:56682/v1/metrics";
var metricsProtocol = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_PROTOCOL") ?? "http/protobuf";

Console.WriteLine($"OpenTelemetry Metrics Endpoint: {metricsEndpoint}");
Console.WriteLine($"OpenTelemetry Metrics Protocol: {metricsProtocol}");

// Configure services
builder.Services.AddHttpClient();
builder.Services.AddControllers();

// Configure OpenTelemetry
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => 
    {
        resource.AddService(
            serviceName: Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME") ?? "dotnet-instrumented-test-app",
            serviceVersion: Environment.GetEnvironmentVariable("OTEL_SERVICE_VERSION") ?? "1.0.0")
        .AddAttributes(new Dictionary<string, object>
        {
            ["deployment.environment"] = Environment.GetEnvironmentVariable("OTEL_ENVIRONMENT") ?? "development"
        })
        .AddEnvironmentVariableDetector(); // This automatically handles OTEL_RESOURCE_ATTRIBUTES
    })
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddMeter("dotnet-instrumented-test-app")
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri(metricsEndpoint);
                
                // Configure protocol based on environment variable
                if (metricsProtocol.Equals("grpc", StringComparison.OrdinalIgnoreCase))
                {
                    options.Protocol = OtlpExportProtocol.Grpc;
                    Console.WriteLine("Using gRPC protocol for OTLP metrics export");
                }
                else if (metricsProtocol.Equals("http/protobuf", StringComparison.OrdinalIgnoreCase))
                {
                    options.Protocol = OtlpExportProtocol.HttpProtobuf;
                    Console.WriteLine("Using HTTP/Protobuf protocol for OTLP metrics export");
                }
                else
                {
                    Console.WriteLine($"Unsupported OTLP metrics protocol: {metricsProtocol}, defaulting to HTTP/Protobuf");
                    options.Protocol = OtlpExportProtocol.HttpProtobuf;
                }

                // Export metrics every 5 seconds (similar to nodejs)
                options.ExportProcessorType = ExportProcessorType.Batch;
            });
    });

var app = builder.Build();

app.MapControllers();

Console.WriteLine("OpenTelemetry instrumentation initialized successfully");

app.Run();

[ApiController]
[Route("/")]
public class HomeController : ControllerBase
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly ILogger<HomeController> _logger;
    private static readonly Meter _meter = new("dotnet-instrumented-test-app", "1.0.0");
    
    // Custom metrics (similar to nodejs-instrumented)
    private static readonly Counter<long> _httpRequestsTotal = _meter.CreateCounter<long>("http_requests_total", description: "Total number of HTTP requests");
    private static readonly Histogram<double> _httpRequestDurationMs = _meter.CreateHistogram<double>("http_request_duration_ms", description: "Duration of HTTP requests in milliseconds");
    private static readonly Counter<long> _httpErrorsTotal = _meter.CreateCounter<long>("http_errors_total", description: "Total number of HTTP errors");
    private static readonly Counter<long> _cowsSoldTotal = _meter.CreateCounter<long>("cows_sold_total", description: "Total number of cows sold");

    public HomeController(IHttpClientFactory httpClientFactory, ILogger<HomeController> logger)
    {
        _httpClientFactory = httpClientFactory;
        _logger = logger;
    }

    [HttpGet]
    public IActionResult Get()
    {
        var stopwatch = Stopwatch.StartNew();
        
        try
        {
            var labels = new Dictionary<string, object?>
            {
                ["method"] = "GET",
                ["route"] = "/",
                ["status_code"] = "200"
            };

            _httpRequestsTotal.Add(1, labels.ToArray());
            _cowsSoldTotal.Add(1, new KeyValuePair<string, object?>[]
            {
                new("cow_type", "Holstein"),
                new("endpoint", Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT")),
                new("protocol", Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_METRICS_PROTOCOL"))
            });

            _logger.LogInformation(".NET instrumented application is running!");
            
            return Ok(new { 
                message = ".NET instrumented application is running!",
                timestamp = DateTime.UtcNow.ToString("O"),
                service = Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME"),
                version = Environment.GetEnvironmentVariable("OTEL_SERVICE_VERSION")
            });
        }
        finally
        {
            stopwatch.Stop();
            var labels = new Dictionary<string, object?>
            {
                ["method"] = "GET",
                ["route"] = "/",
                ["status_code"] = "200"
            };
            _httpRequestDurationMs.Record(stopwatch.ElapsedMilliseconds, labels.ToArray());
        }
    }

    [HttpGet("health")]
    public IActionResult Health()
    {
        return Ok(new { status = "healthy", timestamp = DateTime.UtcNow.ToString("O") });
    }

    [HttpGet("metrics")]
    public IActionResult Metrics()
    {
        return Ok(new { message = "Metrics endpoint - integrate with Prometheus exporter as needed" });
    }

    [HttpGet("call-target")]
    public async Task<IActionResult> CallTarget()
    {
        var stopwatch = Stopwatch.StartNew();
        var statusCode = 200;
        
        try
        {
            if (new Random().NextDouble() < 0.4)
            {
                statusCode = 500;
                throw new Exception("An unexpected error occurred");
            }

            var targetUrl = Environment.GetEnvironmentVariable("TARGET_URL");
            if (string.IsNullOrEmpty(targetUrl))
            {
                statusCode = 500;
                return StatusCode(500, new { error = "TARGET_URL environment variable not set" });
            }

            try
            {
                var client = _httpClientFactory.CreateClient();
                var response = await client.GetAsync(targetUrl);
                var responseText = await response.Content.ReadAsStringAsync();
                statusCode = (int)response.StatusCode;
                
                _logger.LogInformation("Successfully called target URL: {TargetUrl}, Status: {StatusCode}", targetUrl, statusCode);
                
                return StatusCode(statusCode, new { 
                    target_url = targetUrl,
                    response = responseText,
                    timestamp = DateTime.UtcNow.ToString("O")
                });
            }
            catch (Exception ex)
            {
                statusCode = 500;
                _logger.LogError(ex, "Failed to reach target URL: {TargetUrl}", targetUrl);
                return StatusCode(500, new { error = $"Failed to reach {targetUrl}: {ex.Message}" });
            }
        }
        catch (Exception ex)
        {
            statusCode = 500;
            _logger.LogError(ex, "Unexpected error in call-target endpoint");
            return StatusCode(500, new { error = ex.Message });
        }
        finally
        {
            stopwatch.Stop();
            var labels = new Dictionary<string, object?>
            {
                ["method"] = "GET",
                ["route"] = "/call-target",
                ["status_code"] = statusCode.ToString()
            };

            _httpRequestsTotal.Add(1, labels.ToArray());
            _httpRequestDurationMs.Record(stopwatch.ElapsedMilliseconds, labels.ToArray());
            
            if (statusCode >= 400)
            {
                _httpErrorsTotal.Add(1, labels.ToArray());
            }
        }
    }

    [HttpGet("generate-load")]
    public async Task<IActionResult> GenerateLoad([FromQuery] int iterations = 10)
    {
        var stopwatch = Stopwatch.StartNew();
        var results = new List<object>();
        var targetUrl = Environment.GetEnvironmentVariable("TARGET_URL") ?? "http://localhost:3001/";

        _logger.LogInformation("Starting load generation with {Iterations} iterations to {TargetUrl}", iterations, targetUrl);

        for (int i = 0; i < iterations; i++)
        {
            try
            {
                var client = _httpClientFactory.CreateClient();
                var iterationStopwatch = Stopwatch.StartNew();
                
                var response = await client.GetAsync(targetUrl);
                var responseText = await response.Content.ReadAsStringAsync();
                
                iterationStopwatch.Stop();
                
                results.Add(new
                {
                    iteration = i + 1,
                    status_code = (int)response.StatusCode,
                    duration_ms = iterationStopwatch.ElapsedMilliseconds,
                    success = response.IsSuccessStatusCode
                });

                // Add some delay between requests
                await Task.Delay(100);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in iteration {Iteration}", i + 1);
                results.Add(new
                {
                    iteration = i + 1,
                    error = ex.Message,
                    success = false
                });
            }
        }

        stopwatch.Stop();

        var labels = new Dictionary<string, object?>
        {
            ["method"] = "GET",
            ["route"] = "/generate-load",
            ["status_code"] = "200"
        };

        _httpRequestsTotal.Add(1, labels.ToArray());
        _httpRequestDurationMs.Record(stopwatch.ElapsedMilliseconds, labels.ToArray());

        return Ok(new
        {
            message = $"Load generation completed with {iterations} iterations",
            total_duration_ms = stopwatch.ElapsedMilliseconds,
            target_url = targetUrl,
            results = results,
            timestamp = DateTime.UtcNow.ToString("O")
        });
    }
}
