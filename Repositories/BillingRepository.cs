using Npgsql;
using NpgsqlTypes;
using VetClinic.Models;

namespace VetClinic.Repositories;

// Послуги, рахунки й оплати.
public sealed class BillingRepository(NpgsqlConnection connection, Func<NpgsqlTransaction?> transaction) : IBillingRepository
{
    public async Task<int> RegisterPaymentAsync(int invoiceId, decimal amount, string method, int actorId)
    {
        const string sql = "SELECT fn_register_payment(@invoice, @amount, @method, @actor)";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        cmd.Parameters.AddWithValue("invoice", invoiceId);
        cmd.Parameters.Add("amount", NpgsqlDbType.Numeric).Value = amount;
        cmd.Parameters.Add("method", NpgsqlDbType.Text).Value = method;
        cmd.Parameters.AddWithValue("actor", actorId);
        return (int)(await cmd.ExecuteScalarAsync() ?? throw new InvalidOperationException("Не повернуто ID платежу."));
    }

    public async Task<List<InvoiceInfo>> GetInvoicesAsync()
    {
        const string sql = @"SELECT invoice_id, appointment_id, pet_name, owner_name, total, paid, balance, status::text
                             FROM v_invoices_overview ORDER BY invoice_id";
        await using var cmd = new NpgsqlCommand(sql, connection, transaction());
        await using var reader = await cmd.ExecuteReaderAsync();
        var result = new List<InvoiceInfo>();
        while (await reader.ReadAsync())
            result.Add(new InvoiceInfo(reader.GetInt32(0), reader.GetInt32(1), reader.GetString(2), reader.GetString(3),
                reader.GetDecimal(4), reader.GetDecimal(5), reader.GetDecimal(6), reader.GetString(7)));
        return result;
    }
}
