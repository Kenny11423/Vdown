import argparse
import os
import sys

from downloader import __version__
from downloader.core import VideoDownloader
from downloader.utils import (
    is_valid_url,
    detect_platform,
    format_duration,
    format_size,
    extract_available_qualities,
    check_ffmpeg,
)


def prompt_choice(prompt_text: str, valid_choices: list[str], default: str) -> str:
    """Prompt user for a choice with a default value."""
    while True:
        try:
            val = input(f"{prompt_text} (default {default}): ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nCancelled.")
            sys.exit(0)
        if not val:
            return default
        if val in valid_choices:
            return val
        print(f"Invalid choice. Please enter one of: {', '.join(valid_choices)}")


def interactive_download_flow(url: str, downloader: VideoDownloader, default_mp3: bool = False, quality_arg: str = None):
    """Core interactive flow: prompt MP4/MP3 then prompt dynamic qualities."""
    print("Fetching video details...")
    info = downloader.get_info(url)
    if not info:
        print("Failed to retrieve video information. Please check the URL or try with --cookies.")
        sys.exit(1)

    title = info.get("title", "Unknown Title")
    uploader = info.get("uploader") or info.get("channel") or "Unknown"
    duration = format_duration(info.get("duration"))
    platform = detect_platform(url)

    print("-" * 50)
    print(f"Title:    {title}")
    print(f"Platform: {platform}")
    print(f"Uploader: {uploader}")
    print(f"Duration: {duration}")
    print("-" * 50)

    # Step 1: Choose format (MP4 or MP3)
    if default_mp3:
        format_choice = "2"
    elif quality_arg:
        format_choice = "1"
    else:
        print("\nSelect format:")
        print("  [1] MP4 (Video)")
        print("  [2] MP3 (Audio)")
        format_choice = prompt_choice("Choice [1-2]", ["1", "2"], default="1")

    # Step 2: Handle MP3
    if format_choice == "2":
        print("\nDownloading audio as MP3...")
        saved_file = downloader.download(url, audio_only=True)
        if saved_file and os.path.isfile(saved_file):
            size_str = format_size(os.path.getsize(saved_file))
            print(f"\nDone! File saved to: {saved_file} ({size_str})")
        else:
            print("\nDownload failed.")
        return

    # Step 3: Handle MP4 -> Extract dynamic video qualities from source
    qualities = extract_available_qualities(info)
    selected_height = None
    selected_format_id = None
    selected_label = "Best available"

    if quality_arg:
        # User specified quality flag (e.g. 1080)
        if quality_arg.isdigit():
            selected_height = int(quality_arg)
            selected_label = f"{quality_arg}p"
        else:
            selected_height = None
            selected_label = "Best"
    else:
        print("\nAvailable video qualities:")
        choices = []
        for idx, q in enumerate(qualities, 1):
            choices.append(str(idx))
            print(f"  [{idx}] {q['label']}")

        choice_idx = int(prompt_choice(f"Choice [1-{len(qualities)}]", choices, default="1"))
        chosen_quality = qualities[choice_idx - 1]
        selected_height = chosen_quality["height"]
        selected_format_id = chosen_quality["format_id"]
        selected_label = chosen_quality["label"]

    print(f"\nDownloading video ({selected_label})...")
    saved_file = downloader.download(
        url,
        audio_only=False,
        height=selected_height,
        format_id=selected_format_id if not selected_height else None,
    )

    if saved_file and os.path.isfile(saved_file):
        size_str = format_size(os.path.getsize(saved_file))
        print(f"\nDone! File saved to: {saved_file} ({size_str})")
    else:
        print("\nDownload failed.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="vdown",
        description="Simple CLI downloader for YouTube, Shorts, Facebook Reels, TikTok, and more.",
    )
    parser.add_argument(
        "url",
        nargs="?",
        default=None,
        help="Video URL (YouTube, Shorts, Facebook Reel, TikTok, etc.)",
    )
    default_dir = os.path.expanduser("~/Downloads")
    parser.add_argument(
        "-o", "--output",
        dest="output_dir",
        default=default_dir,
        help=f"Output directory (default: {default_dir})",
    )
    parser.add_argument(
        "-a", "--audio", "--mp3",
        dest="audio_only",
        action="store_true",
        help="Directly download audio as MP3 without prompting",
    )
    parser.add_argument(
        "-q", "--quality",
        dest="quality",
        default=None,
        help="Target video quality (e.g. 1080, 720, 480, best)",
    )
    parser.add_argument(
        "-y", "--yes",
        dest="auto_yes",
        action="store_true",
        help="Skip prompts and download best MP4 automatically",
    )
    parser.add_argument(
        "--cookies",
        dest="cookies_browser",
        choices=["zen", "zen-browser", "firefox", "chrome", "edge", "brave", "opera", "vivaldi", "chromium"],
        help="Extract browser cookies (e.g. zen, firefox, chrome) for restricted/private videos",
    )
    parser.add_argument(
        "--cookies-file",
        dest="cookies_file",
        help="Path to cookies.txt file",
    )
    parser.add_argument(
        "--impersonate",
        dest="impersonate",
        default=None,
        help="Client to impersonate to bypass Cloudflare anti-bot (e.g. chrome, safari)",
    )
    parser.add_argument(
        "-i", "--info",
        action="store_true",
        help="Display video details and available qualities without downloading",
    )
    parser.add_argument(
        "-v", "--version",
        action="version",
        version=f"VDownloader CLI v{__version__}",
    )
    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()

    url = args.url
    if not url:
        try:
            url = input("Enter video URL: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nCancelled.")
            sys.exit(0)

    if not is_valid_url(url):
        print(f"Error: Invalid URL '{url}'. Must start with http:// or https://")
        sys.exit(1)

    downloader = VideoDownloader(
        output_dir=args.output_dir,
        cookies_browser=args.cookies_browser,
        cookies_file=args.cookies_file,
        impersonate=args.impersonate,
    )

    if args.info:
        print("Fetching video details...")
        info = downloader.get_info(url)
        if not info:
            sys.exit(1)
        print("-" * 50)
        print(f"Title:    {info.get('title')}")
        print(f"Platform: {detect_platform(url)}")
        print(f"Uploader: {info.get('uploader') or info.get('channel') or 'Unknown'}")
        print(f"Duration: {format_duration(info.get('duration'))}")
        print("-" * 50)
        print("Available video qualities:")
        for idx, q in enumerate(extract_available_qualities(info), 1):
            print(f"  [{idx}] {q['label']}")
        return

    if args.auto_yes:
        # Non-interactive best download
        print(f"Downloading best MP4 for: {url}")
        saved_file = downloader.download(url, audio_only=False)
        if saved_file and os.path.isfile(saved_file):
            print(f"Done! File saved to: {saved_file} ({format_size(os.path.getsize(saved_file))})")
        return

    # Interactive flow
    interactive_download_flow(
        url=url,
        downloader=downloader,
        default_mp3=args.audio_only,
        quality_arg=args.quality,
    )


if __name__ == "__main__":
    main()
