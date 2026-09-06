import os
import sys
from typing import Optional
import yt_dlp
from yt_dlp.utils import DownloadError

from downloader.utils import check_js_runtime, check_ffmpeg


class DownloaderLogger:
    """Silences internal yt-dlp debug logs while keeping warnings minimal."""

    def debug(self, msg: str):
        pass

    def info(self, msg: str):
        pass

    def warning(self, msg: str):
        ignored = [
            "JavaScript runtime",
            "Remote component",
            "Automatic challenge solver",
            "Ignoring unsupported remote component",
        ]
        if not any(ign in msg for ign in ignored):
            print(f"[Warning] {msg}")

    def error(self, msg: str):
        if "HTTP Error 404" in msg or "unavailable" in msg.lower():
            print(f"[Error] {msg}")


class VideoDownloader:
    """Core downloader engine wrapping yt-dlp with optimized defaults."""

    def __init__(
        self,
        output_dir: Optional[str] = None,
        cookies_browser: Optional[str] = None,
        cookies_file: Optional[str] = None,
    ):
        default_dir = os.path.expanduser("~/Downloads")
        self.output_dir = os.path.abspath(os.path.expanduser(output_dir)) if output_dir else default_dir
        self.cookies_browser = cookies_browser
        self.cookies_file = cookies_file
        
        os.makedirs(self.output_dir, exist_ok=True)
        self.js_runtime, _ = check_js_runtime()
        self.has_ffmpeg = check_ffmpeg()

    def _build_options(self) -> dict:
        opts = {
            "quiet": True,
            "no_warnings": True,
            "noprogress": True,
            "logger": DownloaderLogger(),
            "outtmpl": os.path.join(self.output_dir, "%(title).150B [%(id)s].%(ext)s"),
            "windowsfilenames": True,
            "retries": 10,
            "fragment_retries": 10,
            "http_headers": {
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                    "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
                ),
                "Accept-Language": "en-US,en;q=0.9",
            },
        }

        # Enable Node.js challenge solver for YouTube n-sig
        if self.js_runtime:
            opts["js_runtimes"] = {self.js_runtime: {}}
            opts["remote_components"] = {"ejs:github"}

        if self.cookies_browser:
            opts["cookiesfrombrowser"] = (self.cookies_browser, None, None, None)
        elif self.cookies_file and os.path.isfile(self.cookies_file):
            opts["cookiefile"] = self.cookies_file

        return opts

    def get_info(self, url: str) -> Optional[dict]:
        """Fetch video metadata and available formats without downloading."""
        opts = self._build_options()
        opts["noplaylist"] = True

        try:
            with yt_dlp.YoutubeDL(opts) as ydl:
                return ydl.extract_info(url, download=False)
        except DownloadError as e:
            err_msg = str(e)
            print(f"\n[Error] Unable to fetch video info: {err_msg}")
            if "login" in err_msg.lower() or "bot" in err_msg.lower():
                print("Tip: If the video is restricted or requires login, try: --cookies chrome")
            return None
        except Exception as e:
            print(f"\n[Error] Unexpected error: {e}")
            return None

    def download(
        self,
        url: str,
        audio_only: bool = False,
        height: Optional[int] = None,
        format_id: Optional[str] = None,
    ) -> Optional[str]:
        """
        Download media with simple terminal progress and FFmpeg merging.
        Returns downloaded file path on success, or None on failure.
        """
        opts = self._build_options()
        opts["noplaylist"] = True

        if audio_only:
            opts["format"] = "bestaudio/best"
            opts["postprocessors"] = [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ]
        elif format_id:
            opts["format"] = f"{format_id}+bestaudio/best/{format_id}"
            if self.has_ffmpeg:
                opts["merge_output_format"] = "mp4"
        elif height:
            opts["format"] = (
                f"bestvideo[height<={height}][ext=mp4]+bestaudio[ext=m4a]/"
                f"bestvideo[height<={height}]+bestaudio/"
                f"best[height<={height}][ext=mp4]/"
                f"best[height<={height}]/best"
            )
            if self.has_ffmpeg:
                opts["merge_output_format"] = "mp4"
        else:
            opts["format"] = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best"
            if self.has_ffmpeg:
                opts["merge_output_format"] = "mp4"

        last_status_line_len = 0

        def progress_hook(d):
            nonlocal last_status_line_len
            status = d.get("status")
            if status == "downloading":
                downloaded = d.get("downloaded_bytes", 0)
                total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
                speed = d.get("speed") or 0
                eta = d.get("eta")

                pct = f"{(downloaded / total * 100):.1f}%" if total else "N/A"
                dl_mb = f"{downloaded / (1024 * 1024):.1f}"
                tot_mb = f"{total / (1024 * 1024):.1f}MB" if total else "N/A"
                spd_mb = f"{speed / (1024 * 1024):.1f}MB/s" if speed else "N/A"
                eta_s = f"{int(eta)}s" if eta is not None else "N/A"

                bar_len = 24
                if total:
                    filled = min(bar_len, int(bar_len * downloaded / total))
                    arrow = ">" if filled < bar_len else ""
                    bar = "=" * filled + arrow + " " * (bar_len - filled - len(arrow))
                else:
                    bar = " " * bar_len

                line = f"\rDownloading: [{bar}] {pct:>6} | {dl_mb}/{tot_mb} | {spd_mb:>9} | ETA {eta_s:>4}"
                last_status_line_len = len(line)
                sys.stdout.write(line)
                sys.stdout.flush()

            elif status == "finished":
                sys.stdout.write("\n")
                sys.stdout.flush()

        def postprocessor_hook(d):
            status = d.get("status")
            pp = d.get("postprocessor")
            if status == "started":
                if pp == "Merger":
                    print("Merging video and audio streams...")
                elif pp == "ExtractAudio":
                    print("Converting audio to MP3...")

        opts["progress_hooks"] = [progress_hook]
        opts["postprocessor_hooks"] = [postprocessor_hook]

        try:
            with yt_dlp.YoutubeDL(opts) as ydl:
                info = ydl.extract_info(url, download=True)
                downloaded_file = None
                if info:
                    req = info.get("requested_downloads")
                    if req and len(req) > 0:
                        downloaded_file = req[0].get("filepath")
                    if not downloaded_file:
                        downloaded_file = ydl.prepare_filename(info)
                        if audio_only:
                            base, _ = os.path.splitext(downloaded_file)
                            downloaded_file = base + ".mp3"
                        elif not downloaded_file.endswith(".mp4"):
                            base, _ = os.path.splitext(downloaded_file)
                            downloaded_file = base + ".mp4"
                return downloaded_file
        except DownloadError as e:
            print(f"\n[Error] Download failed: {e}")
            return None
        except Exception as e:
            print(f"\n[Error] Unexpected error during download: {e}")
            return None
