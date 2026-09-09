using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;

namespace HrAutomation.Infrastructure.Persistence;

/// <summary>The uniform single-row result set every workflow-critical procedure in
/// ../Database/scripts/07-create-stored-procedures.sql returns (see that file's header comment).</summary>
public sealed record ProcResult(bool Success, string? Message, Guid? EntityId, Guid? WorkflowInstanceId, Guid? CorrelationId, string? ErrorCode);

/// <summary>Invokes a stored procedure from the section-14 catalog and reads back its uniform
/// Success/Message/EntityId/WorkflowInstanceId/CorrelationId/ErrorCode result set. Used instead of
/// EF Core LINQ for multi-entity, security-sensitive, or workflow-critical actions - see
/// Persistence/README.md "When to use EF Core vs. a stored procedure".</summary>
public static class StoredProcedureExecutor
{
    public static async Task<ProcResult> ExecuteAsync(
        DatabaseFacade database, string procedureName, IEnumerable<SqlParameter> parameters, CancellationToken ct = default)
    {
        var connection = (SqlConnection)database.GetDbConnection();
        var wasClosed = connection.State != ConnectionState.Open;
        if (wasClosed)
        {
            await connection.OpenAsync(ct);
        }

        try
        {
            await using var command = connection.CreateCommand();
            command.CommandType = CommandType.StoredProcedure;
            command.CommandText = procedureName;
            if (database.CurrentTransaction is not null)
            {
                command.Transaction = (SqlTransaction)database.CurrentTransaction.GetDbTransaction();
            }
            foreach (var parameter in parameters)
            {
                command.Parameters.Add(parameter);
            }

            await using var reader = await command.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct))
            {
                throw new InvalidOperationException($"{procedureName} returned no result set.");
            }

            return new ProcResult(
                reader.GetBoolean(reader.GetOrdinal("Success")),
                ReadNullableString(reader, "Message"),
                ReadNullableGuid(reader, "EntityId"),
                ReadNullableGuid(reader, "WorkflowInstanceId"),
                ReadNullableGuid(reader, "CorrelationId"),
                ReadNullableString(reader, "ErrorCode"));
        }
        finally
        {
            if (wasClosed)
            {
                await connection.CloseAsync();
            }
        }
    }

    public static SqlParameter Param(string name, object? value, SqlDbType type) =>
        new(name, type) { Value = value ?? DBNull.Value };

    private static string? ReadNullableString(SqlDataReader reader, string column)
    {
        var ordinal = reader.GetOrdinal(column);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    private static Guid? ReadNullableGuid(SqlDataReader reader, string column)
    {
        var ordinal = reader.GetOrdinal(column);
        return reader.IsDBNull(ordinal) ? null : reader.GetGuid(ordinal);
    }
}
