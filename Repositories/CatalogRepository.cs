using Npgsql;
using VetClinic.Models;
namespace VetClinic.Repositories;
public sealed class CatalogRepository(NpgsqlConnection connection, Func<NpgsqlTransaction?> transaction) : ICatalogRepository
{
    public async Task<List<SpeciesItem>> GetSpeciesAsync()
    {
        await using var cmd = new NpgsqlCommand("SELECT id, name FROM v_species_catalog ORDER BY name", connection, transaction());
        await using var reader = await cmd.ExecuteReaderAsync();
        var result = new List<SpeciesItem>();
        while (await reader.ReadAsync()) result.Add(new(reader.GetInt32(0), reader.GetString(1)));
        return result;
    }
    public async Task<List<BreedItem>> GetBreedsAsync(int speciesId)
    {
        await using var cmd = new NpgsqlCommand("SELECT id, species_id, name FROM v_breeds_catalog WHERE species_id=@id ORDER BY name", connection, transaction());
        cmd.Parameters.AddWithValue("id", speciesId);
        await using var reader = await cmd.ExecuteReaderAsync();
        var result = new List<BreedItem>();
        while (await reader.ReadAsync()) result.Add(new(reader.GetInt32(0), reader.GetInt32(1), reader.GetString(2)));
        return result;
    }
    public async Task<List<VeterinarianItem>> GetVetsAsync()
    {
        await using var cmd = new NpgsqlCommand("SELECT id, first_name, last_name, specializations FROM v_active_veterinarians ORDER BY last_name, first_name", connection, transaction());
        await using var reader = await cmd.ExecuteReaderAsync();
        var result = new List<VeterinarianItem>();
        while (await reader.ReadAsync()) result.Add(new(reader.GetInt32(0), reader.GetString(1) + " " + reader.GetString(2), reader.GetString(3)));
        return result;
    }
    public Task<int> CreateSpeciesAsync(string name) => CreateAsync("SELECT fn_create_species(@name)", name, null);
    public Task<int> CreateBreedAsync(int speciesId, string name) => CreateAsync("SELECT fn_create_breed(@species, @name)", name, speciesId);
    private async Task<int> CreateAsync(string sql, string name, int? speciesId)
    {
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        cmd.Parameters.AddWithValue("name", name);
        if (speciesId.HasValue) cmd.Parameters.AddWithValue("species", speciesId.Value);
        return (int)(await cmd.ExecuteScalarAsync() ?? throw new InvalidOperationException("Не отримано ідентифікатор довідника."));
    }
}
