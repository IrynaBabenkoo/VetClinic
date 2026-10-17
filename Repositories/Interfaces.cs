using VetClinic.Models;
namespace VetClinic.Repositories;

public interface IOwnerRepository
{
    Task<List<Owner>> GetActiveAsync();
    Task<int> CreateAsync(string firstName, string lastName, string phone, int actorId, string? email = null);
}

public interface IPetRepository
{
    Task<List<Pet>> GetActiveAsync();
    Task<int> RegisterAsync(int ownerId, int? breedId, string name, int actorId);
    Task SoftDeleteAsync(int petId, int actorId);
    Task<List<OverdueVaccination>> GetOverdueVaccinationsAsync();
}

public interface IAppointmentRepository
{
    Task<List<Appointment>> GetScheduleAsync();
    Task<int> ScheduleAsync(int petId, int vetId, DateTime startUtc, DateTime endUtc, string reason, int actorId);
    Task CancelAsync(int appointmentId, int actorId);
}

public interface IBillingRepository
{
    Task<int> RegisterPaymentAsync(int invoiceId, decimal amount, string method, int actorId);
    Task<List<InvoiceInfo>> GetInvoicesAsync();
}

public interface ICatalogRepository
{
    Task<List<SpeciesItem>> GetSpeciesAsync();
    Task<List<BreedItem>> GetBreedsAsync(int speciesId);
    Task<List<VeterinarianItem>> GetVetsAsync();
    Task<int> CreateSpeciesAsync(string name);
    Task<int> CreateBreedAsync(int speciesId, string name);
}
