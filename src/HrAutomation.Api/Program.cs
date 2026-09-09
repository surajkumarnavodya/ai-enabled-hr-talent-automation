using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using FluentValidation;
using HrAutomation.Agents;
using HrAutomation.Agents.Applications;
using HrAutomation.Agents.CvIngestion;
using HrAutomation.Agents.Discrepancies;
using HrAutomation.Agents.Employees;
using HrAutomation.Agents.GreenForm;
using HrAutomation.Agents.Interviews;
using HrAutomation.Agents.Offers;
using HrAutomation.Agents.Orchestration;
using HrAutomation.Agents.Stubs;
using HrAutomation.Agents.Tan;
using HrAutomation.Api.Auth;
using HrAutomation.Api.ErrorHandling;
using HrAutomation.Api.HealthChecks;
using HrAutomation.Api.Middleware;
using HrAutomation.Application.Approvals;
using HrAutomation.Application.Audit;
using HrAutomation.Application.Contracts;
using HrAutomation.Application.Guardrails;
using HrAutomation.Application.Orchestration;
using HrAutomation.Application.Skills;
using HrAutomation.Application.Validation;
using HrAutomation.Application.Security;
using HrAutomation.Infrastructure.Approvals;
using HrAutomation.Infrastructure.Audit;
using HrAutomation.Infrastructure.Persistence;
using HrAutomation.Infrastructure.Security;
using HrAutomation.Rag;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

// --- Configuration ---
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
var jwtSection = builder.Configuration.GetSection(JwtOptions.SectionName);
var jwtIssuer = jwtSection["Issuer"] ?? "hr-automation-dev";
var jwtAudience = jwtSection["Audience"] ?? "hr-automation-api";
var jwtSigningKey = jwtSection["SigningKey"] ?? "dev-only-signing-key-change-me-before-any-non-local-use-32chars";

// --- Persistence ---
// HrAutomationDb (database-first, see HrAutomation.Infrastructure/Database/) is the sole
// database from here on; the earlier code-first HrAutomation database/HrDbContext is retired.
var connectionString = builder.Configuration.GetConnectionString("HrAutomationDb")
    ?? "Server=(localdb)\\mssqllocaldb;Database=HrAutomationDb;Trusted_Connection=True;MultipleActiveResultSets=true";
builder.Services.AddDbContext<HrAutomationDbContext>(options => options.UseSqlServer(connectionString));

// --- Health checks: reachability only, never leaks server name/connection details ---
builder.Services.AddHealthChecks().AddCheck<DatabaseHealthCheck>("database");

// --- Cross-cutting application services ---
builder.Services.AddScoped<IAuditLogger, AuditLogger>();
builder.Services.AddScoped<IApprovalGateService, ApprovalGateService>();
builder.Services.AddScoped<IEffectivePermissionService, EffectivePermissionService>();
builder.Services.AddSingleton<IGuardrailPipeline, GuardrailPipeline>();
builder.Services.AddScoped<IWorkflowOrchestrator, WorkflowOrchestrator>();
builder.Services.AddSingleton<IPolicyRetrievalSkill, NotConfiguredPolicyRetrievalSkill>();

// --- Skills: the two fully-implemented flows, then every not-yet-implemented stub ---
builder.Services.AddScoped<IMalwareScanner, NoOpMalwareScanner>();
builder.Services.AddSingleton<ICvFieldExtractor, SimpleCvExtractor>();
builder.Services.AddScoped<ISkill, CvIngestionSkill>();
builder.Services.AddScoped<ISkill, CreateTanSkill>();
builder.Services.AddScoped<ISkill, TanApprovalSkill>();
builder.Services.AddScoped<ISkill, CreateInterviewSkill>();
builder.Services.AddScoped<ISkill, InterviewFeedbackSkill>();
builder.Services.AddScoped<ISkill, CreateOfferSkill>();
builder.Services.AddScoped<ISkill, OfferApprovalSkill>();
builder.Services.AddScoped<ISkill, OfferSendSkill>();
builder.Services.AddScoped<ISkill, OfferAcceptanceSkill>();
builder.Services.AddScoped<ISkill, CreateGreenFormLinkSkill>();
builder.Services.AddScoped<ISkill, DiscrepancyResolveSkill>();
builder.Services.AddScoped<ISkill, DiscrepancyReuploadRequestSkill>();
builder.Services.AddScoped<ISkill, ShortlistApprovalSkill>();
builder.Services.AddScoped<ISkill, EmployeeConversionSkill>();
foreach (var stub in StubSkillCatalog.CreateAll())
{
    builder.Services.AddSingleton<ISkill>(stub);
}
builder.Services.AddScoped<ISkillRegistry, SkillRegistry>();

// --- Validation ---
builder.Services.AddScoped<IValidator<CreateTanRequest>, CreateTanRequestValidator>();
builder.Services.AddScoped<IValidator<ApproveTanRequest>, ApproveTanRequestValidator>();
builder.Services.AddScoped<IValidator<ScheduleInterviewRequest>, ScheduleInterviewRequestValidator>();
builder.Services.AddScoped<IValidator<SubmitInterviewFeedbackRequest>, SubmitInterviewFeedbackRequestValidator>();
builder.Services.AddScoped<IValidator<CreateOfferRequest>, CreateOfferRequestValidator>();
builder.Services.AddScoped<IValidator<SubmitGreenFormRequest>, SubmitGreenFormRequestValidator>();
builder.Services.AddScoped<IValidator<ResolveDiscrepancyRequest>, ResolveDiscrepancyRequestValidator>();
builder.Services.AddScoped<IValidator<RequestReuploadRequest>, RequestReuploadRequestValidator>();

// --- Auth: dev-only symmetric-key JWT until a real OIDC/OAuth 2.1 provider is wired in ---
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwtIssuer,
            ValidateAudience = true,
            ValidAudience = jwtAudience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSigningKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30)
        };
    });
builder.Services.AddAuthorization();

// --- MVC / JSON: snake_case wire format + string enums, matching the section-12 envelope exactly ---
builder.Services.AddControllers().AddJsonOptions(options =>
{
    options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower;
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo { Title = "HR Automation Agent API", Version = "v1" });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Paste the access_token returned from /api/v1/dev/token (Development only)."
    });

    options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecuritySchemeReference("Bearer", document),
            new List<string>()
        }
    });
});

builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

// --- CORS: deny-by-default. Cors:AllowedOrigins is empty in appsettings.json (production
// default - same-origin/reverse-proxy deployment assumed unless explicitly configured);
// appsettings.Development.json adds the Vite dev server origin. Never a wildcard alongside
// credentialed (cookie) auth - see docs/05-security-governance/frontend-security.md. ---
var corsAllowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
builder.Services.AddCors(options =>
{
    options.AddPolicy("Default", policy =>
    {
        if (corsAllowedOrigins.Length > 0)
        {
            policy.WithOrigins(corsAllowedOrigins)
                .AllowAnyHeader()
                .AllowAnyMethod()
                .AllowCredentials();
        }
        // else: no origins configured - CORS stays fully closed (no AddPolicy calls succeed
        // for any cross-origin request), which is correct for a same-origin deployment.
    });
});

// --- Observability: console exporter only for now - swap in an OTLP exporter before production ---
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService("HrAutomation.Api"))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddConsoleExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddConsoleExporter());

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseExceptionHandler();
app.UseHttpsRedirection();

app.UseCors("Default");

app.UseMiddleware<CorrelationIdMiddleware>();

app.UseAuthentication();
app.UseAuthorization();

app.UseMiddleware<TenantSessionContextMiddleware>();
app.UseMiddleware<IdempotencyKeyMiddleware>();

app.MapControllers();

// Unauthenticated by design (standard for monitoring/load-balancer probes) - the response
// body is a fixed, non-sensitive shape only ("status" + per-check "status"), never a
// connection string, server name, or exception detail. See DatabaseHealthCheck.
app.MapHealthChecks("/health", new HealthCheckOptions
{
    ResponseWriter = async (context, report) =>
    {
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsJsonAsync(new
        {
            status = report.Status.ToString(),
            checks = report.Entries.Select(e => new { name = e.Key, status = e.Value.Status.ToString() })
        });
    }
});

app.Run();

// Exposes the implicit top-level Program class to WebApplicationFactory<Program> in the test project.
public partial class Program;
