namespace VetClinic.Models;
public record SpeciesItem(int Id, string Name);
public record BreedItem(int Id, int SpeciesId, string Name);
public record VeterinarianItem(int Id, string Name, string Specializations);
