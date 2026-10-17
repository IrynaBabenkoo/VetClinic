using VetClinic.Data;
using VetClinic.Infrastructure;
using VetClinic.UI;

Console.OutputEncoding = System.Text.Encoding.UTF8;
Console.InputEncoding = System.Text.Encoding.UTF8;

var connectionString = Environment.GetEnvironmentVariable("VETCLINIC_CONNECTION");
if (string.IsNullOrWhiteSpace(connectionString))
{
    Console.WriteLine("Не задано змінну середовища VETCLINIC_CONNECTION. Вкажіть підключення до PostgreSQL (див. README.md).");
    return;
}

// Поточний користувач = 1 (admin).
const int demoActorId = 1;

while (true)
{
    MenuActions.PrintMenu();
    Console.Write("Ваш вибір: ");
    var option = Console.ReadLine()?.Trim();
    if (option is null or "0") break;

    try
    {
        await using var uow = await UnitOfWork.OpenAsync(connectionString);
        await new MenuActions(uow, demoActorId).ExecuteAsync(option);
    }
    catch (OperationCanceledException)
    {
        Console.WriteLine("Введення перервано.");
        break;
    }
    catch (Exception ex)
    {
        Console.WriteLine("ПОМИЛКА: " + ErrorTranslator.Translate(ex));
    }
}

Console.WriteLine("До побачення!");
