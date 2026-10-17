using Npgsql;
using NpgsqlTypes;
using VetClinic.Models;
namespace VetClinic.Repositories;

public sealed class AppointmentRepository(NpgsqlConnection connection, Func<NpgsqlTransaction?> transaction) : IAppointmentRepository
{
    public async Task<List<Appointment>> GetScheduleAsync()
    {
        const string sql = @"SELECT appointment_id, vet_id, vet_first_name, vet_last_name, pet_id, pet_name,
                                    start_time, end_time, status::text, reason
                             FROM v_doctor_schedule ORDER BY start_time";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        await using var reader = await cmd.ExecuteReaderAsync();
        var result = new List<Appointment>();
        while (await reader.ReadAsync())
            result.Add(new Appointment(reader.GetInt32(0), reader.GetInt32(1),
                reader.GetString(2) + " " + reader.GetString(3),
                reader.GetInt32(4), reader.GetString(5),
                reader.GetDateTime(6), reader.GetDateTime(7), reader.GetString(8),
                reader.IsDBNull(9) ? null : reader.GetString(9)));
        return result;
    }

    public async Task<int> ScheduleAsync(int petId, int vetId, DateTime startUtc, DateTime endUtc, string reason, int actorId)
    {
        const string sql = "SELECT fn_schedule_appointment(@pet, @vet, @start, @end, @reason, @actor)";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        cmd.Parameters.AddWithValue("pet", petId);
        cmd.Parameters.AddWithValue("vet", vetId);
        cmd.Parameters.Add("start", NpgsqlDbType.TimestampTz).Value = startUtc;
        cmd.Parameters.Add("end", NpgsqlDbType.TimestampTz).Value = endUtc;
        cmd.Parameters.AddWithValue("reason", reason);
        cmd.Parameters.AddWithValue("actor", actorId);
        return (int)(await cmd.ExecuteScalarAsync() ?? throw new InvalidOperationException("Не повернуто ID прийому."));
    }

    public async Task CancelAsync(int appointmentId, int actorId)
    {
        await using var cmd = new NpgsqlCommand("CALL sp_cancel_appointment(@appointment, @actor)", connection, transaction());
        cmd.Parameters.AddWithValue("appointment", appointmentId);
        cmd.Parameters.AddWithValue("actor", actorId);
        await cmd.ExecuteNonQueryAsync();
    }

}
