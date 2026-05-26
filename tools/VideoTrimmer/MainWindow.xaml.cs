using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Threading;
using Microsoft.Win32;

namespace VideoTrimmer;

public partial class MainWindow : Window
{
    private readonly DispatcherTimer _positionTimer;
    private bool _isPlaying;
    private bool _isDragging;
    private TimeSpan _duration;
    private double _trimStart;
    private double _trimEnd;
    private const double FrameStep = 1.0 / 60.0;
    private CancellationTokenSource? _regenerateCts;

    public MainWindow()
    {
        InitializeComponent();

        _positionTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(80) };
        _positionTimer.Tick += PositionTimer_Tick;

        TrimOverlay.SizeChanged += (_, _) => UpdateTrimMarkers();

        OutputDirBox.Text = @"O:\Footage\Highline\Website";
    }

    // ── Timer ─────────────────────────────────────────────────────────────────

    private void PositionTimer_Tick(object? sender, EventArgs e)
    {
        if (_isDragging || _duration.TotalSeconds <= 0) return;
        var frac = VideoPlayer.Position.TotalSeconds / _duration.TotalSeconds;
        TimelineSlider.Value = Math.Clamp(frac, 0, 1);
        CurrentTimeLabel.Text = FormatTime(VideoPlayer.Position);
    }

    // ── File browsing ─────────────────────────────────────────────────────────

    private void BrowseVideo_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog
        {
            Title = "Select source video",
            Filter = "Video files|*.mp4;*.mov;*.avi;*.mkv;*.webm;*.m4v|All files|*.*",
            InitialDirectory = @"O:\Footage\Highline\Tricks",
        };
        if (dlg.ShowDialog() != true) return;

        VideoPathBox.Text = dlg.FileName;

        if (string.IsNullOrWhiteSpace(OutputDirBox.Text))
            OutputDirBox.Text = Path.GetDirectoryName(dlg.FileName) ?? "";

        VideoPlayer.Source = new Uri(dlg.FileName);
        VideoPlayer.Play();
        VideoPlayer.Pause();
        _positionTimer.Start();
        SetStatus("Video loaded — set trim points and trick ID, then Generate.");
    }

    private void VideoPathBox_LostFocus(object sender, RoutedEventArgs e)
    {
        var path = VideoPathBox.Text.Trim();
        if (string.IsNullOrEmpty(path) || !File.Exists(path)) return;

        if (string.IsNullOrWhiteSpace(OutputDirBox.Text))
            OutputDirBox.Text = Path.GetDirectoryName(path) ?? "";

        VideoPlayer.Source = new Uri(path);
        VideoPlayer.Play();
        VideoPlayer.Pause();
        _positionTimer.Start();
        SetStatus("Video loaded — set trim points and trick ID, then Generate.");
    }

    private void BrowseOutput_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFolderDialog { Title = "Select output directory", InitialDirectory = @"O:\Footage\Highline\Website" };
        if (dlg.ShowDialog() == true)
            OutputDirBox.Text = dlg.FolderName;
    }

    // ── Media events ──────────────────────────────────────────────────────────

    private void VideoPlayer_MediaOpened(object sender, RoutedEventArgs e)
    {
        if (!VideoPlayer.NaturalDuration.HasTimeSpan) return;

        _duration = VideoPlayer.NaturalDuration.TimeSpan;
        DurationLabel.Text = FormatTime(_duration);
        _trimStart = 0;
        _trimEnd = _duration.TotalSeconds;
        TrimStartBox.Text = "0.000";
        TrimEndBox.Text = _trimEnd.ToString("F3");
        UpdateTrimMarkers();
    }

    private void VideoPlayer_MediaEnded(object sender, RoutedEventArgs e)
    {
        _isPlaying = false;
        PlayPauseBtn.Content = "▶";
        VideoPlayer.Position = TimeSpan.Zero;
    }

    // ── Playback controls ─────────────────────────────────────────────────────

    private void PlayPause_Click(object sender, RoutedEventArgs e)
    {
        if (_isPlaying)
        {
            VideoPlayer.Pause();
            _isPlaying = false;
            PlayPauseBtn.Content = "▶";
        }
        else
        {
            VideoPlayer.Play();
            _isPlaying = true;
            PlayPauseBtn.Content = "⏸";
        }
    }

    private void Restart_Click(object sender, RoutedEventArgs e)
    {
        VideoPlayer.Position = TimeSpan.Zero;
        TimelineSlider.Value = 0;
        CurrentTimeLabel.Text = FormatTime(TimeSpan.Zero);
    }

    private void StepBack_Click(object sender, RoutedEventArgs e)
    {
        var pos = TimeSpan.FromSeconds(Math.Max(0, VideoPlayer.Position.TotalSeconds - FrameStep));
        VideoPlayer.Position = pos;
        CurrentTimeLabel.Text = FormatTime(pos);
    }

    private void StepForward_Click(object sender, RoutedEventArgs e)
    {
        var pos = TimeSpan.FromSeconds(Math.Min(_duration.TotalSeconds, VideoPlayer.Position.TotalSeconds + FrameStep));
        VideoPlayer.Position = pos;
        CurrentTimeLabel.Text = FormatTime(pos);
    }

    // ── Timeline scrubber ─────────────────────────────────────────────────────

    private void TimelineSlider_PreviewMouseDown(object sender, MouseButtonEventArgs e)
    {
        _isDragging = true;
        // Jump immediately to the clicked position. LargeChange is set to near-zero
        // so the RepeatButton command that fires afterwards is harmless.
        if (TimelineSlider.ActualWidth > 0)
        {
            const double pad = 7.0; // thumb radius — matches the TrimOverlay margin
            TimelineSlider.Value = Math.Clamp(
                (e.GetPosition(TimelineSlider).X - pad) / (TimelineSlider.ActualWidth - pad * 2),
                0, 1);
        }
    }

    private void TimelineSlider_PreviewMouseUp(object sender, MouseButtonEventArgs e)
    {
        _isDragging = false;
        if (_duration.TotalSeconds > 0)
        {
            var pos = TimeSpan.FromSeconds(TimelineSlider.Value * _duration.TotalSeconds);
            VideoPlayer.Position = pos;
            CurrentTimeLabel.Text = FormatTime(pos);
        }
    }

    private void TimelineSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_isDragging && _duration.TotalSeconds > 0)
            CurrentTimeLabel.Text = FormatTime(TimeSpan.FromSeconds(e.NewValue * _duration.TotalSeconds));
    }

    // ── Trim controls ─────────────────────────────────────────────────────────

    private void SetStart_Click(object sender, RoutedEventArgs e)
    {
        _trimStart = VideoPlayer.Position.TotalSeconds;
        TrimStartBox.Text = _trimStart.ToString("F3");
        UpdateTrimMarkers();
    }

    private void SetEnd_Click(object sender, RoutedEventArgs e)
    {
        _trimEnd = VideoPlayer.Position.TotalSeconds;
        TrimEndBox.Text = _trimEnd.ToString("F3");
        UpdateTrimMarkers();
    }

    private void PlayFromStart_Click(object sender, RoutedEventArgs e)
    {
        if (_duration.TotalSeconds <= 0) return;
        VideoPlayer.Position = TimeSpan.FromSeconds(_trimStart);
        TimelineSlider.Value = _trimStart / _duration.TotalSeconds;
        VideoPlayer.Play();
        _isPlaying = true;
        PlayPauseBtn.Content = "⏸";
    }

    private void PlayFromEnd_Click(object sender, RoutedEventArgs e)
    {
        if (_duration.TotalSeconds <= 0) return;
        VideoPlayer.Position = TimeSpan.FromSeconds(_trimEnd);
        TimelineSlider.Value = _trimEnd / _duration.TotalSeconds;
        VideoPlayer.Play();
        _isPlaying = true;
        PlayPauseBtn.Content = "⏸";
    }

    private void TrimBox_TextChanged(object sender, TextChangedEventArgs e)
    {
        if (double.TryParse(TrimStartBox?.Text, out var start)) _trimStart = start;
        if (double.TryParse(TrimEndBox?.Text,   out var end))   _trimEnd   = end;
        UpdateTrimMarkers();
    }

    private void UpdateTrimMarkers()
    {
        if (_duration.TotalSeconds <= 0 || TrimOverlay.ActualWidth <= 0) return;

        var w      = TrimOverlay.ActualWidth;
        var startX = Math.Clamp(_trimStart / _duration.TotalSeconds, 0, 1) * w;
        var endX   = Math.Clamp(_trimEnd   / _duration.TotalSeconds, 0, 1) * w;

        Canvas.SetLeft(TrimStartLine, startX);
        Canvas.SetLeft(TrimEndLine,   endX);
        Canvas.SetLeft(TrimRegion,    startX);
        TrimRegion.Width = Math.Max(0, endX - startX);
    }

    // ── Generate ──────────────────────────────────────────────────────────────

    private async void Generate_Click(object sender, RoutedEventArgs e)
    {
        var inputPath  = VideoPathBox.Text.Trim();
        var trickId    = TrickIdBox.Text.Trim();
        var outputBase = OutputDirBox.Text.Trim();

        if (string.IsNullOrEmpty(inputPath))  { SetStatus("Error: select a source video first.");    return; }
        if (string.IsNullOrEmpty(trickId))    { SetStatus("Error: enter a Trick ID.");               return; }
        if (string.IsNullOrEmpty(outputBase)) { SetStatus("Error: select an output directory.");     return; }
        if (_trimStart >= _trimEnd)           { SetStatus("Error: trim start must be before trim end."); return; }

        GenerateBtn.IsEnabled    = false;
        BrowseVideoBtn.IsEnabled = false;
        RegenerateBtn.IsEnabled  = false;

        try
        {
            var outDir      = Path.Combine(outputBase, trickId);
            Directory.CreateDirectory(outDir);

            var forwardPath       = Path.Combine(outDir, "forward.mp4");
            var reversedPath      = Path.Combine(outDir, "reversed.mp4");
            var forwardMobilePath = Path.Combine(outDir, "forward_mobile.mp4");
            var reversedMobilePath = Path.Combine(outDir, "reversed_mobile.mp4");

            SetStatus("Encoding forward.mp4 (1/4)…");
            await RunFfmpegAsync(BuildArgs(inputPath, _trimStart, _trimEnd, forwardPath, reverse: false));

            SetStatus("Encoding reversed.mp4 (2/4)…");
            await RunFfmpegAsync(BuildArgs(inputPath, _trimStart, _trimEnd, reversedPath, reverse: true));

            SetStatus("Encoding forward_mobile.mp4 (3/4)…");
            await RunFfmpegAsync(BuildArgs(inputPath, _trimStart, _trimEnd, forwardMobilePath, reverse: false, mobile: true));

            SetStatus("Encoding reversed_mobile.mp4 (4/4)…");
            await RunFfmpegAsync(BuildArgs(inputPath, _trimStart, _trimEnd, reversedMobilePath, reverse: true, mobile: true));

            WriteManifestEntry(Path.Combine(outputBase, "manifest.csv"), trickId, inputPath, _trimStart, _trimEnd);
            SetStatus($"Done! Saved to {outDir}");
        }
        catch (FfmpegNotFoundException)
        {
            SetStatus("Error: ffmpeg not found. Install ffmpeg and add it to PATH, then restart.");
        }
        catch (FfmpegException ex)
        {
            SetStatus($"ffmpeg failed (exit {ex.ExitCode}). Check that the source video is valid.");
        }
        catch (Exception ex)
        {
            SetStatus($"Error: {ex.Message}");
        }
        finally
        {
            GenerateBtn.IsEnabled    = true;
            BrowseVideoBtn.IsEnabled = true;
            RegenerateBtn.IsEnabled  = true;
        }
    }

    private void Stop_Click(object sender, RoutedEventArgs e) => _regenerateCts?.Cancel();

    private async void RegenerateAll_Click(object sender, RoutedEventArgs e)
    {
        var outputBase = OutputDirBox.Text.Trim();
        var defaultManifest = string.IsNullOrEmpty(outputBase) ? "" : Path.Combine(outputBase, "manifest.csv");

        var dlg = new OpenFileDialog
        {
            Title = "Select manifest.csv",
            Filter = "CSV files|*.csv|All files|*.*",
            InitialDirectory = File.Exists(defaultManifest) ? outputBase : @"O:\Footage\Highline\Website",
            FileName = File.Exists(defaultManifest) ? defaultManifest : "",
        };
        if (dlg.ShowDialog() != true) return;

        List<(string trickId, string sourceFile, double trimStart, double trimEnd)> entries;
        try
        {
            entries = ParseManifest(dlg.FileName);
        }
        catch (Exception ex)
        {
            SetStatus($"Error reading manifest: {ex.Message}");
            return;
        }

        if (entries.Count == 0) { SetStatus("Manifest is empty."); return; }

        GenerateBtn.IsEnabled    = false;
        BrowseVideoBtn.IsEnabled = false;
        RegenerateBtn.IsEnabled  = false;
        StopBtn.IsEnabled        = true;

        _regenerateCts = new CancellationTokenSource();
        var ct = _regenerateCts.Token;

        try
        {
            for (int i = 0; i < entries.Count; i++)
            {
                var (trickId, sourceFile, trimStart, trimEnd) = entries[i];
                var prefix = $"[{i + 1}/{entries.Count}] Trick {trickId}:";

                if (!File.Exists(sourceFile))
                {
                    SetStatus($"{prefix} source not found — skipping.");
                    continue;
                }

                var outDir = Path.Combine(
                    string.IsNullOrEmpty(outputBase) ? Path.GetDirectoryName(dlg.FileName)! : outputBase,
                    trickId);
                Directory.CreateDirectory(outDir);

                SetStatus($"{prefix} Encoding forward.mp4 (1/4)…");
                await RunFfmpegAsync(BuildArgs(sourceFile, trimStart, trimEnd, Path.Combine(outDir, "forward.mp4"), reverse: false), ct);

                SetStatus($"{prefix} Encoding reversed.mp4 (2/4)…");
                await RunFfmpegAsync(BuildArgs(sourceFile, trimStart, trimEnd, Path.Combine(outDir, "reversed.mp4"), reverse: true), ct);

                SetStatus($"{prefix} Encoding forward_mobile.mp4 (3/4)…");
                await RunFfmpegAsync(BuildArgs(sourceFile, trimStart, trimEnd, Path.Combine(outDir, "forward_mobile.mp4"), reverse: false, mobile: true), ct);

                SetStatus($"{prefix} Encoding reversed_mobile.mp4 (4/4)…");
                await RunFfmpegAsync(BuildArgs(sourceFile, trimStart, trimEnd, Path.Combine(outDir, "reversed_mobile.mp4"), reverse: true, mobile: true), ct);
            }
            SetStatus($"Done — {entries.Count} trick(s) regenerated.");
        }
        catch (OperationCanceledException) { SetStatus("Regeneration stopped."); }
        catch (FfmpegNotFoundException)    { SetStatus("Error: ffmpeg not found. Install ffmpeg and add it to PATH, then restart."); }
        catch (FfmpegException ex)         { SetStatus($"ffmpeg failed (exit {ex.ExitCode}). Check that the source file is valid."); }
        catch (Exception ex)               { SetStatus($"Error: {ex.Message}"); }
        finally
        {
            _regenerateCts.Dispose();
            _regenerateCts           = null;
            GenerateBtn.IsEnabled    = true;
            BrowseVideoBtn.IsEnabled = true;
            RegenerateBtn.IsEnabled  = true;
            StopBtn.IsEnabled        = false;
        }
    }

    private static List<(string trickId, string sourceFile, double trimStart, double trimEnd)> ParseManifest(string path)
    {
        var entries = new List<(string, string, double, double)>();
        using var reader = new StreamReader(path);
        bool firstLine = true;
        string? line;
        while ((line = reader.ReadLine()) != null)
        {
            if (firstLine) { firstLine = false; continue; } // skip header
            if (string.IsNullOrWhiteSpace(line)) continue;

            var parts = SplitCsvLine(line);
            if (parts.Length < 4) continue;
            if (!double.TryParse(parts[2], out var trimStart)) continue;
            if (!double.TryParse(parts[3], out var trimEnd))   continue;

            entries.Add((parts[0].Trim(), parts[1].Trim().Trim('"'), trimStart, trimEnd));
        }
        return entries;
    }

    private static string[] SplitCsvLine(string line)
    {
        var fields = new List<string>();
        var current = new System.Text.StringBuilder();
        bool inQuotes = false;
        foreach (char c in line)
        {
            if      (c == '"')              inQuotes = !inQuotes;
            else if (c == ',' && !inQuotes) { fields.Add(current.ToString()); current.Clear(); }
            else                            current.Append(c);
        }
        fields.Add(current.ToString());
        return [.. fields];
    }

    private static void WriteManifestEntry(string manifestPath, string trickId, string sourceFile, double trimStart, double trimEnd)
    {
        bool exists = File.Exists(manifestPath);
        using var writer = new StreamWriter(manifestPath, append: true);
        if (!exists)
            writer.WriteLine("TrickId,SourceFile,TrimStart,TrimEnd,GeneratedAt");
        writer.WriteLine($"{trickId},\"{sourceFile}\",{trimStart:F3},{trimEnd:F3},{DateTime.Now:yyyy-MM-dd HH:mm:ss}");
    }

    private static string BuildArgs(string input, double start, double end, string output, bool reverse, bool mobile = false)
    {
        var scale = mobile ? ",scale=720:1280" : "";
        var crf   = mobile ? 26 : 18;

        var vf = reverse
            ? $"trim=start={start:F3}:end={end:F3},setpts=PTS-STARTPTS,crop=1080:1920{scale},reverse"
            : $"trim=start={start:F3}:end={end:F3},setpts=PTS-STARTPTS,crop=1080:1920{scale}";

        return $"-y -i \"{input}\" -vf \"{vf}\" -c:v libx264 -crf {crf} -preset medium -r 60 -g 30 -keyint_min 30 -sc_threshold 0 -an \"{output}\"";
    }

    private static async Task RunFfmpegAsync(string args, CancellationToken ct = default)
    {
        var psi = new ProcessStartInfo("ffmpeg", args)
        {
            UseShellExecute = false,
            CreateNoWindow  = true,
        };

        Process process;
        try
        {
            process = Process.Start(psi) ?? throw new FfmpegException(0);
        }
        catch (System.ComponentModel.Win32Exception)
        {
            throw new FfmpegNotFoundException();
        }

        try
        {
            await process.WaitForExitAsync(ct);
        }
        catch (OperationCanceledException)
        {
            try { process.Kill(); } catch { }
            process.Dispose();
            throw;
        }

        var code = process.ExitCode;
        process.Dispose();

        if (code != 0) throw new FfmpegException(code);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private void SetStatus(string message) => StatusLabel.Text = message;

    private static string FormatTime(TimeSpan t) =>
        $"{(int)t.TotalMinutes}:{t.Seconds:D2}.{t.Milliseconds:D3}";

    private sealed class FfmpegNotFoundException : Exception { }

    private sealed class FfmpegException(int exitCode)
        : Exception($"ffmpeg exited with code {exitCode}")
    {
        public int ExitCode { get; } = exitCode;
    }
}
