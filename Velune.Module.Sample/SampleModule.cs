using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Velune.Module.Abstractions.Contributions;
using Velune.Module.Abstractions.Hosting;
using Velune.Module.Abstractions.Lifecycle;
using Velune.UI.Modules;

namespace Velune.Module.Sample;

public sealed class SampleModule :
    IVeluneModule,
    IModuleContributionSource,
    IVeluneSurfaceContentProvider
{
    private const string SurfaceContentKey = "sample.main";

    public ModuleContributionSet Contributions { get; } =
        new()
        {
            Rail =
            [
                new RailContributionDescriptor
                {
                    Id = new ContributionId("sample.rail"),
                    DisplayName = "Sample",
                    Icon = "◇",
                    SurfaceId = new ContributionId("sample.surface"),
                    OrderHint = 50
                }
            ],
            Surfaces =
            [
                new SurfaceContributionDescriptor
                {
                    Id = new ContributionId("sample.surface"),
                    ContentKey = SurfaceContentKey,
                    PreferredWidth = 980
                }
            ],
            Commands =
            [
                new CommandContributionDescriptor
                {
                    Id = new ContributionId("sample.ping"),
                    DisplayName = "Sample Ping",
                    Description = "Boundary proof command contribution.",
                    CommandKey = "sample.ping"
                }
            ]
        };

    public ValueTask InitializeAsync(
        ModuleContext context,
        CancellationToken cancellationToken) =>
        ValueTask.CompletedTask;

    public ValueTask ActivateAsync(
        CancellationToken cancellationToken) =>
        ValueTask.CompletedTask;

    public ValueTask DeactivateAsync(
        CancellationToken cancellationToken) =>
        ValueTask.CompletedTask;

    public ValueTask ShutdownAsync(
        CancellationToken cancellationToken) =>
        ValueTask.CompletedTask;

    public UIElement CreateSurfaceContent(
        string contentKey)
    {
        if (!string.Equals(
                contentKey,
                SurfaceContentKey,
                StringComparison.Ordinal))
        {
            throw new KeyNotFoundException(
                $"Unknown surface content key '{contentKey}'.");
        }

        return CreateSurface();
    }

    private static UIElement CreateSurface()
    {
        var root =
            new Grid
            {
                Margin = new Thickness(38)
            };

        root.RowDefinitions.Add(
            new RowDefinition
            {
                Height = GridLength.Auto
            });
        root.RowDefinitions.Add(
            new RowDefinition
            {
                Height = new GridLength(1, GridUnitType.Star)
            });
        root.RowDefinitions.Add(
            new RowDefinition
            {
                Height = GridLength.Auto
            });

        var header =
            new StackPanel();

        header.Children.Add(
            new TextBlock
            {
                Text = "EXTERNAL MODULE",
                FontFamily = new FontFamily("Cascadia Mono"),
                FontSize = 12,
                FontWeight = FontWeights.SemiBold,
                Foreground = Brush("#6F8394")
            });

        header.Children.Add(
            new TextBlock
            {
                Text = "VELUNE Sample",
                Margin = new Thickness(0, 10, 0, 0),
                FontFamily = new FontFamily("Segoe UI Variable Display"),
                FontSize = 38,
                FontWeight = FontWeights.SemiBold,
                Foreground = Brush("#EEF5FB")
            });

        header.Children.Add(
            new TextBlock
            {
                Text = "Loaded from a separate repository through public contracts only.",
                Margin = new Thickness(0, 8, 0, 0),
                FontFamily = new FontFamily("Segoe UI Variable Text"),
                FontSize = 15,
                Foreground = Brush("#8FA2B2")
            });

        root.Children.Add(header);

        var proof =
            new Border
            {
                Margin = new Thickness(0, 34, 0, 34),
                Padding = new Thickness(24),
                BorderBrush = Brush("#334657"),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(14),
                VerticalAlignment = VerticalAlignment.Center
            };

        Grid.SetRow(
            proof,
            1);

        var proofText =
            new StackPanel();

        proofText.Children.Add(
            ProofLine("PUBLIC CONTRACT", "Velune.Module.Abstractions"));
        proofText.Children.Add(
            ProofLine("PUBLIC UI KIT", "Velune.UI"));
        proofText.Children.Add(
            ProofLine("RAIL", "sample.rail"));
        proofText.Children.Add(
            ProofLine("SURFACE", "980 × 1008 requested"));
        proofText.Children.Add(
            ProofLine("COMMAND", "sample.ping"));

        proof.Child =
            proofText;

        root.Children.Add(
            proof);

        var footer =
            new TextBlock
            {
                Text = "No DesignLab · Runtime · Platform.Windows reference",
                FontFamily = new FontFamily("Cascadia Mono"),
                FontSize = 12,
                Foreground = Brush("#607485")
            };

        Grid.SetRow(
            footer,
            2);

        root.Children.Add(
            footer);

        return new SampleSurface(
            root);
    }

    private static UIElement ProofLine(
        string label,
        string value)
    {
        var row =
            new Grid
            {
                Margin = new Thickness(0, 7, 0, 7)
            };

        row.ColumnDefinitions.Add(
            new ColumnDefinition
            {
                Width = new GridLength(180)
            });
        row.ColumnDefinitions.Add(
            new ColumnDefinition());

        row.Children.Add(
            new TextBlock
            {
                Text = label,
                FontFamily = new FontFamily("Cascadia Mono"),
                FontSize = 12,
                Foreground = Brush("#7890A2")
            });

        var valueText =
            new TextBlock
            {
                Text = value,
                FontFamily = new FontFamily("Segoe UI Variable Text"),
                FontSize = 14,
                Foreground = Brush("#C8D5DF")
            };

        Grid.SetColumn(
            valueText,
            1);

        row.Children.Add(
            valueText);

        return row;
    }

    private static SolidColorBrush Brush(
        string hex)
    {
        var brush =
            new SolidColorBrush(
                (Color)ColorConverter.ConvertFromString(hex));

        brush.Freeze();
        return brush;
    }
}

internal sealed class SampleSurface : UserControl
{
    public SampleSurface(
        UIElement content)
    {
        Content =
            content;
    }
}