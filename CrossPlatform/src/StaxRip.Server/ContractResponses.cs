using System.Text.Json;
using StaxRip.Contracts;

namespace StaxRip.Server;

public static class ContractResponses
{
    public static Task WriteHealthAsync(
        HttpResponse response,
        HealthResponse health,
        CancellationToken cancellationToken = default) =>
        WriteJsonAsync(response, health, cancellationToken);

    public static Task WriteCapabilitiesAsync(
        HttpResponse response,
        CapabilityResponse capabilities,
        CancellationToken cancellationToken = default) =>
        WriteJsonAsync(response, capabilities, cancellationToken);

    public static Task WriteErrorAsync(
        HttpResponse response,
        int statusCode,
        ApiErrorCode code,
        string message,
        CancellationToken cancellationToken = default)
    {
        response.StatusCode = statusCode;

        var payload = new ErrorResponse(
            ApiContract.SchemaVersion,
            ApiContract.ApiVersion,
            new ApiError(code, message));

        return WriteJsonAsync(response, payload, cancellationToken);
    }

    private static async Task WriteJsonAsync<T>(
        HttpResponse response,
        T payload,
        CancellationToken cancellationToken)
    {
        response.ContentType = "application/json; charset=utf-8";
        await JsonSerializer.SerializeAsync(
            response.Body,
            payload,
            ContractJson.Options,
            cancellationToken).ConfigureAwait(false);
    }
}
