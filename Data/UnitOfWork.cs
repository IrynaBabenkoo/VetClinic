using Npgsql;
using VetClinic.Repositories;

namespace VetClinic.Data;

public interface IUnitOfWork : IAsyncDisposable
{
    IOwnerRepository Owners { get; }
    IPetRepository Pets { get; }
    IAppointmentRepository Appointments { get; }
    IBillingRepository Billing { get; }
    ICatalogRepository Catalog { get; }

    Task BeginAsync(int actorId);
    Task CommitAsync();
    Task RollbackAsync();

    Task RunInTransactionAsync(int actorId, Func<Task> work);
}

public sealed class UnitOfWork : IUnitOfWork
{
    private readonly NpgsqlConnection _connection;
    private NpgsqlTransaction? _transaction;

    public IOwnerRepository Owners { get; }
    public IPetRepository Pets { get; }
    public IAppointmentRepository Appointments { get; }
    public IBillingRepository Billing { get; }
    public ICatalogRepository Catalog { get; }

    private UnitOfWork(NpgsqlConnection connection)
    {
        _connection = connection;
        Owners = new OwnerRepository(connection, () => _transaction);
        Pets = new PetRepository(connection, () => _transaction);
        Appointments = new AppointmentRepository(connection, () => _transaction);
        Billing = new BillingRepository(connection, () => _transaction);
        Catalog = new CatalogRepository(connection, () => _transaction);
    }

    public static async Task<UnitOfWork> OpenAsync(string connectionString)
    {
        var connection = new NpgsqlConnection(connectionString);
        try
        {
            await connection.OpenAsync();
        }
        catch
        {
            await connection.DisposeAsync();
            throw;
        }
        return new UnitOfWork(connection);
    }

    public async Task BeginAsync(int actorId)
    {
        if (_transaction is not null) throw new InvalidOperationException("Транзакція вже відкрита.");
        _transaction = await _connection.BeginTransactionAsync();
        try
        {
            await using var cmd = new NpgsqlCommand("CALL sp_set_current_user(@actor)", _connection, _transaction);
            cmd.Parameters.AddWithValue("actor", actorId);
            await cmd.ExecuteNonQueryAsync();
        }
        catch
        {
            await RollbackAsync();
            throw;
        }
    }

    public async Task CommitAsync()
    {
        if (_transaction is null) throw new InvalidOperationException("Немає активної транзакції.");
        await _transaction.CommitAsync();
        await _transaction.DisposeAsync();
        _transaction = null;
    }

    public async Task RollbackAsync()
    {
        if (_transaction is null) return;
        try { await _transaction.RollbackAsync(); }
        finally { await _transaction.DisposeAsync(); _transaction = null; }
    }

    public async Task RunInTransactionAsync(int actorId, Func<Task> work)
    {
        await BeginAsync(actorId);
        try
        {
            await work();
            await CommitAsync();
        }
        catch
        {
            await RollbackAsync();
            throw;
        }
    }

    public async ValueTask DisposeAsync()
    {
        await RollbackAsync();
        await _connection.DisposeAsync();
    }
}
