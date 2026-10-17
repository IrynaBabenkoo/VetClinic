using System.Globalization;
namespace VetClinic.Infrastructure;

public static class Ua
{
    public static string AppointmentStatus(string status) => status switch
    {
        "scheduled" => "Запланований",
        "in_progress" => "Триває",
        "completed" => "Завершений",
        "cancelled" => "Скасований",
        "no_show" => "Не з'явився",
        _ => status
    };

    public static string InvoiceStatus(string status) => status switch
    {
        "draft" => "Чернетка",
        "issued" => "Виставлений",
        "partially_paid" => "Частково оплачений",
        "paid" => "Оплачений",
        "cancelled" => "Скасований",
        _ => status
    };

    public static string Money(decimal value) => value.ToString("0.00", CultureInfo.InvariantCulture) + " грн";
}
