using Avalonia;

class Program
{
    [STAThread]
    static void Main(string[] args) =>
        BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);

    static AppBuilder BuildAvaloniaApp() =>
        AppBuilder.Configure<VideoTrimmer.App>()
                  .UsePlatformDetect()
                  .LogToTrace();
}
