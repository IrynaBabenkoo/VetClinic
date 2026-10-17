using VetClinic.Data;
using VetClinic.Models;
using VetClinic.Infrastructure;
using static VetClinic.UI.ConsoleInput;
namespace VetClinic.UI;

public sealed class MenuActions(IUnitOfWork uow, int actorId)
{
    public static void PrintMenu()
    {
        Console.WriteLine("\n========== ВЕТЕРИНАРНА КЛІНІКА ==========");
        Console.WriteLine("1. Переглянути власників");
        Console.WriteLine("2. Переглянути тварин");
        Console.WriteLine("3. Переглянути розклад прийомів");
        Console.WriteLine("4. Зареєструвати власника та тварину");
        Console.WriteLine("5. Записати тварину на прийом");
        Console.WriteLine("6. Логічно видалити тварину");
        Console.WriteLine("7. Прострочені вакцинації");
        Console.WriteLine("8. Рахунки та заборгованість");
        Console.WriteLine("9. Прийняти оплату");
        Console.WriteLine("10. Скасувати прийом");
        Console.WriteLine("11. Перевірити Rollback");
        Console.WriteLine("0. Вихід");
    }

    public async Task ExecuteAsync(string option)
    {
        switch (option)
        {
            case "1": await ShowOwnersAsync(); break;
            case "2": await ShowPetsAsync(); break;
            case "3": await ShowScheduleAsync(); break;
            case "4": await RegisterOwnerAndPetAsync(); break;
            case "5": await ScheduleAppointmentAsync(); break;
            case "6": await SoftDeletePetAsync(); break;
            case "7": await ShowOverdueVaccinationsAsync(); break;
            case "8": await ShowInvoicesAsync(); break;
            case "9": await AcceptPaymentAsync(); break;
            case "10": await CancelAppointmentAsync(); break;
            case "11": await DemonstrateRollbackAsync(); break;
            default: Console.WriteLine("Невідомий пункт меню."); break;
        }
    }

    private static T Choose<T>(IReadOnlyList<T> options, Func<T, string> label, string title)
    {
        if (options.Count == 0) throw new InvalidOperationException("Немає доступних записів для вибору.");
        Console.WriteLine("\n" + title);
        for (int i = 0; i < options.Count; i++) Console.WriteLine($"{i + 1}. {label(options[i])}");
        return options[ReadInt("Ваш вибір: ", 1, options.Count) - 1];
    }

    private async Task ShowOwnersAsync()
    {
        var owners = await uow.Owners.GetActiveAsync();
        if (owners.Count == 0) { Console.WriteLine("Власників немає."); return; }
        foreach (var o in owners)
            Console.WriteLine($"#{o.Id} {o.FirstName} {o.LastName}, тел.: {o.Phone}" + (o.Email is null ? "" : $", {o.Email}"));
    }

    private async Task ShowPetsAsync()
    {
        var pets = await uow.Pets.GetActiveAsync();
        if (pets.Count == 0) { Console.WriteLine("Тварин немає."); return; }
        foreach (var p in pets)
            Console.WriteLine($"#{p.Id} {p.Name} ({p.Species ?? "вид не вказано"}, {p.Breed ?? "порода не вказана"}), власник: {p.OwnerName}");
    }

    private async Task ShowScheduleAsync()
    {
        var items = await uow.Appointments.GetScheduleAsync();
        if (items.Count == 0) { Console.WriteLine("Прийомів немає."); return; }
        foreach (var a in items)
        {
            var start = KyivTime.FromUtc(a.StartTime);
            var end = KyivTime.FromUtc(a.EndTime);
            Console.WriteLine($"#{a.Id} | {start:dd.MM.yyyy HH:mm}-{end:HH:mm} | лікар: {a.VetName} | {a.PetName} | {Ua.AppointmentStatus(a.Status)}"
                              + (string.IsNullOrWhiteSpace(a.Reason) ? "" : $" | {a.Reason}"));
        }
    }

    private async Task ShowOverdueVaccinationsAsync()
    {
        var items = await uow.Pets.GetOverdueVaccinationsAsync();
        if (items.Count == 0) { Console.WriteLine("Прострочених вакцинацій немає."); return; }
        foreach (var v in items)
            Console.WriteLine($"{v.PetName} (#{v.PetId}): {v.VaccineName}, мала бути до {v.NextDueDate:dd.MM.yyyy}");
    }

    private async Task ShowInvoicesAsync()
    {
        var items = await uow.Billing.GetInvoicesAsync();
        if (items.Count == 0) { Console.WriteLine("Рахунків немає."); return; }
        foreach (var i in items) Console.WriteLine(FormatInvoice(i));
    }

    private static string FormatInvoice(InvoiceInfo i) =>
        $"Рахунок #{i.InvoiceId} (прийом #{i.AppointmentId}) | {i.PetName}, {i.OwnerName} | " +
        $"сума {Ua.Money(i.Total)}, сплачено {Ua.Money(i.Paid)}, залишок {Ua.Money(i.Balance)} | {Ua.InvoiceStatus(i.Status)}";

    //  Unit of Work 

    private async Task RegisterOwnerAndPetAsync()
    {
        Console.WriteLine("\n--- РЕЄСТРАЦІЯ ВЛАСНИКА І ТВАРИНИ ---");
        var first = ReadRequired("Ім'я власника: ");
        var last = ReadRequired("Прізвище власника: ");
        var phone = ReadRequired("Телефон: ");
        var petName = ReadRequired("Кличка тварини: ");
        var species = await uow.Catalog.GetSpeciesAsync();
        Console.WriteLine("\nВиди тварин:");
        for (int i = 0; i < species.Count; i++) Console.WriteLine($"{i + 1}. {species[i].Name}");
        Console.WriteLine($"{species.Count + 1}. Додати новий вид");
        var speciesChoice = ReadInt("Ваш вибір: ", 1, species.Count + 1);
        var newSpeciesName = speciesChoice == species.Count + 1 ? ReadRequired("Назва нового виду: ") : null;
        var existingSpeciesId = newSpeciesName is null ? species[speciesChoice - 1].Id : 0;
        var breeds = newSpeciesName is null ? await uow.Catalog.GetBreedsAsync(existingSpeciesId) : new List<BreedItem>();
        Console.WriteLine("\nПороди:");
        for (int i = 0; i < breeds.Count; i++) Console.WriteLine($"{i + 1}. {breeds[i].Name}");
        Console.WriteLine($"{breeds.Count + 1}. Без породи");
        Console.WriteLine($"{breeds.Count + 2}. Додати нову породу");
        var breedChoice = ReadInt("Ваш вибір: ", 1, breeds.Count + 2);
        var newBreedName = breedChoice == breeds.Count + 2 ? ReadRequired("Назва нової породи: ") : null;
        int? existingBreedId = breedChoice <= breeds.Count ? breeds[breedChoice - 1].Id : null;

        int ownerId = 0, petId = 0;
        try
        {
            await uow.RunInTransactionAsync(actorId, async () =>
            {
                var speciesId = newSpeciesName is null ? existingSpeciesId : await uow.Catalog.CreateSpeciesAsync(newSpeciesName);
                var breedId = newBreedName is null ? existingBreedId : await uow.Catalog.CreateBreedAsync(speciesId, newBreedName);
                ownerId = await uow.Owners.CreateAsync(first, last, phone, actorId);
                petId = await uow.Pets.RegisterAsync(ownerId, breedId, petName, actorId);
            });
        }
        catch
        {
            Console.WriteLine("Транзакцію скасовано: зміни не збережено.");
            throw;
        }
        Console.WriteLine($"Власника і тварину зареєстровано. Номери записів: {ownerId}, {petId}.");
    }

    private async Task ScheduleAppointmentAsync()
    {
        var pets = await uow.Pets.GetActiveAsync();
        var pet = Choose(pets, p => $"{p.Name} — {p.OwnerName} ({p.Species ?? "вид невідомий"})", "Оберіть тварину:");
        var vets = await uow.Catalog.GetVetsAsync();
        var vet = Choose(vets, v => $"{v.Name} — {v.Specializations}", "Оберіть ветеринара:");
        var startUtc = ReadKyivDateTimeAsUtc("Початок (за Києвом, рррр-мм-дд гг:хх): ");
        var minutes = ReadInt("Тривалість у хвилинах: ", 5, 480);
        var reason = ReadRequired("Причина звернення: ");
        int id = 0;
        await uow.RunInTransactionAsync(actorId, async () =>
            id = await uow.Appointments.ScheduleAsync(pet.Id, vet.Id, startUtc, startUtc.AddMinutes(minutes), reason, actorId));
        Console.WriteLine($"Прийом створено, номер {id}.");
    }

    private async Task AcceptPaymentAsync()
    {
        var open = (await uow.Billing.GetInvoicesAsync())
            .Where(i => i.Balance > 0 && (i.Status == "issued" || i.Status == "partially_paid"))
            .ToList();
        if (open.Count == 0) { Console.WriteLine("Немає рахунків, що очікують оплати."); return; }
        var selected = Choose(open, i => FormatInvoice(i), "Оберіть рахунок для оплати:");
        var invoiceId = selected.InvoiceId;
        var amount = ReadDecimal("Сума оплати, грн: ", 0.01m, Math.Min(1_000_000m, selected.Balance));
        Console.WriteLine("Спосіб оплати: 1 — готівка, 2 — картка, 3 — переказ");
        var method = ReadInt("Вибір: ", 1, 3) switch { 1 => "cash", 2 => "card", _ => "transfer" };

        var paymentId = 0;
        await uow.RunInTransactionAsync(actorId, async () =>
            paymentId = await uow.Billing.RegisterPaymentAsync(invoiceId, amount, method, actorId));
        Console.WriteLine($"УСПІХ: платіж #{paymentId} зареєстровано.");

        var invoice = (await uow.Billing.GetInvoicesAsync()).FirstOrDefault(i => i.InvoiceId == invoiceId);
        if (invoice is not null) Console.WriteLine(FormatInvoice(invoice));
    }

    private async Task SoftDeletePetAsync()
    {
        var pets = await uow.Pets.GetActiveAsync();
        var petId = Choose(pets, p => $"{p.Name} — {p.OwnerName}", "Оберіть тварину для логічного видалення:").Id;
        if (!Confirm("Видалити? Запис лишиться в БД як «видалений», історія прийомів збережеться"))
        {
            Console.WriteLine("Скасовано.");
            return;
        }
        await uow.RunInTransactionAsync(actorId, () => uow.Pets.SoftDeleteAsync(petId, actorId));
        Console.WriteLine($"УСПІХ: тварину #{petId} позначено як видалену (soft delete).");
    }
    private async Task CancelAppointmentAsync()
    {
        var scheduled = (await uow.Appointments.GetScheduleAsync())
            .Where(a => a.Status == "scheduled").ToList();
        if (scheduled.Count == 0)
        {
            Console.WriteLine("Немає запланованих прийомів для скасування.");
            return;
        }
        var chosen = Choose(scheduled,
            a => $"{a.PetName} — {a.VetName}, {KyivTime.FromUtc(a.StartTime):dd.MM.yyyy HH:mm}",
            "Оберіть прийом для скасування:");
        if (!Confirm("Скасувати вибраний прийом?"))
        {
            Console.WriteLine("Дію скасовано.");
            return;
        }
        await uow.RunInTransactionAsync(actorId, () => uow.Appointments.CancelAsync(chosen.Id, actorId));
        Console.WriteLine("Прийом скасовано. Час ветеринара звільнено.");
    }

    private async Task DemonstrateRollbackAsync()
    {
        Console.WriteLine("\n--- ПЕРЕВІРКА ROLLBACK ---");
        Console.WriteLine("Буде тимчасово створено власника, після чого реєстрація тварини з неіснуючою породою викличе помилку.");
        if (!Confirm("Запустити демонстрацію?")) return;
        int tempOwnerId = 0;
        await uow.BeginAsync(actorId);
        try
        {
            tempOwnerId = await uow.Owners.CreateAsync(
                "Демо", "Відкат", "+380000000000", actorId);
            Console.WriteLine($"Тимчасово створено власника №{tempOwnerId}.");
            await uow.Pets.RegisterAsync(tempOwnerId, int.MaxValue, "Тест", actorId);
            await uow.RollbackAsync();
            Console.WriteLine("Транзакцію скасовано.");
        }
        catch (Npgsql.PostgresException ex) when (ex.SqlState == "23503")
        {
            await uow.RollbackAsync();
            Console.WriteLine("Очікувана помилка зовнішнього ключа. Виконано ROLLBACK.");
        }
        catch
        {
            await uow.RollbackAsync();
            throw;
        }
        var remained = (await uow.Owners.GetActiveAsync()).Any(o => o.Id == tempOwnerId);
        Console.WriteLine(remained
            ? "ПОМИЛКА: тимчасовий власник залишився в базі."
            : "Перевірено: тимчасовий власник відсутній. Відкат працює.");
    }

}
