using Npgsql;
using NpgsqlTypes;
using VetClinic.Models;

namespace VetClinic.Repositories;

public sealed class PetRepository(NpgsqlConnection connection, Func<NpgsqlTransaction?> transaction) : IPetRepository
{
    public async Task<List<Pet>> GetActiveAsync()
    {
        const string sql = "SELECT id, name, owner_id, owner_first_name, owner_last_name, breed_name, species_name FROM v_active_pets ORDER BY id";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        await using var reader = await cmd.ExecuteReaderAsync();
        var result = new List<Pet>();
        while (await reader.ReadAsync())
            result.Add(new Pet(reader.GetInt32(0), reader.GetString(1), reader.GetInt32(2),
                reader.GetString(3) + " " + reader.GetString(4),
                reader.IsDBNull(5) ? null : reader.GetString(5),
                reader.IsDBNull(6) ? null : reader.GetString(6)));
        return result;
    }

    public async Task<int> RegisterAsync(int ownerId, int? breedId, string name, int actorId)
    {
        const string sql = "SELECT fn_register_pet(@owner, @breed, @name, @actor)";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        cmd.Parameters.AddWithValue("owner", ownerId);
        cmd.Parameters.Add("breed", NpgsqlDbType.Integer).Value = (object?)breedId ?? DBNull.Value;
        cmd.Parameters.AddWithValue("name", name);
        cmd.Parameters.AddWithValue("actor", actorId);
        return (int)(await cmd.ExecuteScalarAsync() ?? throw new InvalidOperationException("Не повернуто ID тварини."));
    }

    public async Task SoftDeleteAsync(int petId, int actorId)
    {
        const string sql = "CALL sp_soft_delete_pet(@pet, @actor)";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        cmd.Parameters.AddWithValue("pet", petId);
        cmd.Parameters.AddWithValue("actor", actorId);
        await cmd.ExecuteNonQueryAsync();
    }

    public async Task<List<OverdueVaccination>> GetOverdueVaccinationsAsync()
    {
        const string sql = "SELECT id, pet_id, pet_name, vaccine_name, next_due_date FROM v_overdue_vaccinations ORDER BY next_due_date";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        await using var reader = await cmd.ExecuteReaderAsync();
        var result = new List<OverdueVaccination>();
        while (await reader.ReadAsync())
            result.Add(new OverdueVaccination(reader.GetInt32(0), reader.GetInt32(1), reader.GetString(2),
                reader.GetString(3), reader.GetDateTime(4)));
        return result;
    }
}
