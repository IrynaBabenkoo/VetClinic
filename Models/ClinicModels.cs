namespace VetClinic.Models;

public record Owner(int Id, string FirstName, string LastName, string Phone, string? Email);

public record Pet(int Id, string Name, int OwnerId, string OwnerName, string? Breed, string? Species);

public record Appointment(int Id, int VetId, string VetName, int PetId, string PetName,
    DateTime StartTime, DateTime EndTime, string Status, string? Reason);

public record Service(int Id, string Name, decimal Price);

public record InvoiceInfo(int InvoiceId, int AppointmentId, string PetName, string OwnerName,
    decimal Total, decimal Paid, decimal Balance, string Status);

public record OverdueVaccination(int Id, int PetId, string PetName, string VaccineName, DateTime NextDueDate);
