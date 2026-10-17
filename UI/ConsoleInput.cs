using System.Globalization;
using VetClinic.Infrastructure;
namespace VetClinic.UI;

public static class ConsoleInput
{
    private static string ReadLine(string prompt)
    {
        Console.Write(prompt);
        return Console.ReadLine()?.Trim() ?? throw new OperationCanceledException("Введення перервано.");
    }

    public static string ReadRequired(string prompt)
    {
        while (true)
        {
            var text = ReadLine(prompt);
            if (text.Length > 0) return text;
            Console.WriteLine("  Значення не може бути порожнім.");
        }
    }

    public static int ReadInt(string prompt, int min = 1, int max = int.MaxValue)
    {
        while (true)
        {
            if (int.TryParse(ReadLine(prompt), NumberStyles.Integer, CultureInfo.InvariantCulture, out var value)
                && value >= min && value <= max)
                return value;
            Console.WriteLine(max == int.MaxValue
                ? $"  Введіть ціле число, не менше {min}."
                : $"  Введіть ціле число від {min} до {max}.");
        }
    }

    public static decimal ReadDecimal(string prompt, decimal min, decimal max)
    {
        while (true)
        {
            var text = ReadLine(prompt).Replace(',', '.');
            if (decimal.TryParse(text, NumberStyles.Number, CultureInfo.InvariantCulture, out var value)
                && value >= min && value <= max)
                return value;
            Console.WriteLine($"  Введіть число від {min.ToString(CultureInfo.InvariantCulture)} до {max.ToString(CultureInfo.InvariantCulture)} (наприклад 10 або 12,5).");
        }
    }

    public static DateTime ReadKyivDateTimeAsUtc(string prompt)
    {
        while (true)
        {
            var text = ReadLine(prompt);
            if (!DateTime.TryParseExact(text, "yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var local))
            {
                Console.WriteLine("  Формат: рррр-мм-дд гг:хх, наприклад 2026-10-20 14:30.");
                continue;
            }
            try { return KyivTime.ToUtc(local); }
            catch (ArgumentException)
            {
                Console.WriteLine("  Такого часу не існує через перехід на літній/зимовий час. Вкажіть інший.");
            }
        }
    }

    public static bool Confirm(string prompt)
    {
        while (true)
        {
            Console.WriteLine(prompt);
            Console.WriteLine("1. Так, підтвердити");
            Console.WriteLine("0. Ні, повернутися");
            Console.Write("Ваш вибір: ");

            string? answer = Console.ReadLine()?.Trim();

            if (answer == "1")
                return true;

            if (answer == "0")
                return false;

            Console.WriteLine("Введіть 1 або 0.");
        }
    }
}
