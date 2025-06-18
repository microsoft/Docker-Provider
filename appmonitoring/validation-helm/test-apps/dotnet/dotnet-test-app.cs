using Microsoft.AspNetCore.Mvc;

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
        if (new Random().NextDouble() < 0.4)
        {
            var ex = new Exception("An unexpected error occurred");
            _logger.LogError(ex, "Random failure in /call-target");
            // Throw to allow OTel to capture the exception
            throw ex;
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
            return StatusCode(500, new { error = $"Failed to reach {targetUrl}: {ex.Message}" });
        }
    }
}