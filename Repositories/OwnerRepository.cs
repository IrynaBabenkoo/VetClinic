using Npgsql;
using NpgsqlTypes;
using VetClinic.Models;

namespace VetClinic.Repositories;

public sealed class OwnerRepository(NpgsqlConnection connection, Func<NpgsqlTransaction?> transaction) : IOwnerRepository
{
    public async Task<List<Owner>> GetActiveAsync()
    {
        const string sql = "SELECT id, first_name, last_name, phone, email FROM v_active_owners ORDER BY id";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        await using var reader = await cmd.ExecuteReaderAsync();
        var owners = new List<Owner>();
        while (await reader.ReadAsync())
            owners.Add(new Owner(reader.GetInt32(0), reader.GetString(1), reader.GetString(2),
                reader.GetString(3), reader.IsDBNull(4) ? null : reader.GetString(4)));
        return owners;
    }

    public async Task<int> CreateAsync(string firstName, string lastName, string phone, int actorId, string? email = null)
    {
        const string sql = "SELECT fn_create_owner(@first, @last, @phone, @actor, @email)";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        cmd.Parameters.AddWithValue("first", firstName);
        cmd.Parameters.AddWithValue("last", lastName);
        cmd.Parameters.AddWithValue("phone", phone);
        cmd.Parameters.AddWithValue("actor", actorId);
        cmd.Parameters.Add("email", NpgsqlDbType.Text).Value = (object?)email ?? DBNull.Value;
        return (int)(await cmd.ExecuteScalarAsync() ?? throw new InvalidOperationException("Не повернуто ID власника."));
    }
}
