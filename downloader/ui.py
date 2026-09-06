from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.text import Text
from rich.progress import (
    Progress,
    SpinnerColumn,
    TextColumn,
    BarColumn,
    DownloadColumn,
    TransferSpeedColumn,
    TimeRemainingColumn,
)
from downloader.utils import (
    format_duration,
    format_size,
    format_views,
    detect_platform,
)

console = Console()


def print_banner():
    """Print the application banner and supported platforms."""
    banner_text = Text()
    banner_text.append("╔════════════════════════════════════════════════════════════╗\n", style="bold cyan")
    banner_text.append("║                   ", style="bold cyan")
    banner_text.append("⚡ VDownloader CLI ⚡", style="bold bright_yellow")
    banner_text.append("                     ║\n", style="bold cyan")
    banner_text.append("║        Multi-Platform Video & Audio Downloader Tool        ║\n", style="dim white")
    banner_text.append("╚════════════════════════════════════════════════════════════╝", style="bold cyan")

    console.print(banner_text)
    
    platforms_text = Text()
    platforms_text.append("  Supported: ", style="bold green")
    platforms_text.append("YouTube • ", style="red")
    platforms_text.append("YouTube Shorts • ", style="bold red")
    platforms_text.append("Facebook Reels • ", style="bold blue")
    platforms_text.append("TikTok • ", style="magenta")
    platforms_text.append("Instagram • ", style="bold magenta")
    platforms_text.append("X/Twitter • ", style="cyan")
    platforms_text.append("1000+ sites", style="italic yellow")
    
    console.print(platforms_text)
    console.print()


def print_info_card(info: dict, url: str):
    """Print a styled card with media metadata."""
    platform_data = detect_platform(url)
    
    title = info.get("title", "Unknown Title")
    uploader = info.get("uploader") or info.get("channel") or info.get("creator") or "Unknown"
    duration = format_duration(info.get("duration"))
    views = format_views(info.get("view_count"))
    webpage_url = info.get("webpage_url", url)
    
    table = Table(show_header=False, box=None, padding=(0, 1))
    table.add_column("Property", style="bold cyan", width=14)
    table.add_column("Value", style="white")

    table.add_row("Platform:", f"{platform_data['badge']} [dim]({platform_data['name']})[/dim]")
    table.add_row("Title:", f"[bold bright_white]{title}[/bold bright_white]")
    table.add_row("Uploader:", f"[yellow]{uploader}[/yellow]")
    table.add_row("Duration:", f"[green]{duration}[/green]")
    table.add_row("Views:", f"[blue]{views}[/blue]")
    table.add_row("URL:", f"[dim underline]{webpage_url}[/dim underline]")

    panel = Panel(
        table,
        title="[bold yellow]📌 Video Information[/bold yellow]",
        border_style="cyan",
        padding=(1, 2),
    )
    console.print(panel)


def print_formats_table(formats: list):
    """Display available video and audio formats in an organized table."""
    table = Table(
        title="[bold yellow]📊 Available Formats[/bold yellow]",
        border_style="bright_blue",
        header_style="bold cyan",
        show_lines=True,
    )

    table.add_column("ID", style="bold yellow", width=8, justify="center")
    table.add_column("Ext", style="green", width=6, justify="center")
    table.add_column("Resolution", style="magenta", width=14, justify="center")
    table.add_column("FPS", style="dim", width=5, justify="center")
    table.add_column("Filesize", style="blue", width=10, justify="right")
    table.add_column("Video Codec", style="cyan", width=14)
    table.add_column("Audio Codec", style="yellow", width=14)
    table.add_column("Type / Note", style="white", width=16)

    for f in formats:
        fid = str(f.get("format_id", ""))
        ext = f.get("ext", "")
        resolution = f.get("resolution") or (
            f"{f.get('width', '?')}x{f.get('height', '?')}"
            if f.get("height")
            else "audio only"
        )
        fps = str(f.get("fps")) if f.get("fps") else "-"
        size = format_size(f.get("filesize") or f.get("filesize_approx"))
        vcodec = f.get("vcodec", "none")
        acodec = f.get("acodec", "none")
        
        # Simplify codec names
        if vcodec and vcodec != "none":
            vcodec = vcodec.split(".")[0]
        if acodec and acodec != "none":
            acodec = acodec.split(".")[0]
            
        note = f.get("format_note", "")
        if vcodec != "none" and acodec != "none":
            kind = "[green]video+audio[/green]"
        elif vcodec != "none":
            kind = "[blue]video only[/blue]"
        elif acodec != "none":
            kind = "[yellow]audio only[/yellow]"
        else:
            kind = "[dim]unknown[/dim]"
            
        if note:
            kind += f" [dim]({note})[/dim]"

        table.add_row(fid, ext, resolution, fps, size, vcodec, acodec, kind)

    console.print(table)


def create_progress_tracker() -> Progress:
    """Create a customized Rich progress bar instance for downloads."""
    return Progress(
        SpinnerColumn(spinner_name="dots"),
        TextColumn("[bold cyan]{task.description}"),
        BarColumn(bar_width=40, style="grey37", complete_style="bold green"),
        TextColumn("[progress.percentage]{task.percentage:>3.1f}%"),
        DownloadColumn(),
        TransferSpeedColumn(),
        TimeRemainingColumn(),
        console=console,
        transient=False,
    )


def print_success(file_path: str, size: str = "N/A", duration: str = "N/A"):
    """Print download completed success card."""
    content = Text()
    content.append("✨ Download Completed Successfully! ✨\n\n", style="bold green")
    content.append("📁 Saved to:  ", style="bold cyan")
    content.append(f"{file_path}\n", style="bold underline white")
    content.append("📦 File Size: ", style="bold cyan")
    content.append(f"{size}\n", style="yellow")
    if duration != "N/A":
        content.append("⏱️ Duration:  ", style="bold cyan")
        content.append(f"{duration}\n", style="magenta")

    panel = Panel(
        content,
        title="[bold green]✅ Success[/bold green]",
        border_style="green",
        padding=(1, 2),
    )
    console.print(panel)


def print_error(message: str, tip: str | None = None):
    """Print a styled error panel with optional helpful hint."""
    text = Text()
    text.append(f"❌ {message}\n", style="bold red")
    if tip:
        text.append(f"\n💡 Hint: {tip}", style="yellow")

    panel = Panel(
        text,
        title="[bold red]Error[/bold red]",
        border_style="red",
        padding=(1, 2),
    )
    console.print(panel)


def print_warning(message: str):
    """Print a styled warning message."""
    console.print(f"[bold yellow]⚠️  {message}[/bold yellow]")


def print_status(message: str):
    """Print an informational status message."""
    console.print(f"[bold cyan]ℹ️  {message}[/bold cyan]")
