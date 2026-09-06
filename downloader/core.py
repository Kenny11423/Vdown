import os
import sys
import time
from typing import Optional
import yt_dlp
from yt_dlp.utils import DownloadError

from downloader.utils import check_js_runtime, check_ffmpeg, find_zen_browser_profile

# Check for curl_cffi for Cloudflare TLS impersonation
try:
    import curl_cffi
    from yt_dlp.networking.impersonate import ImpersonateTarget
    HAS_CURL_CFFI = True
except ImportError:
    HAS_CURL_CFFI = False


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
        impersonate: Optional[str] = None,
    ):
        default_dir = os.path.expanduser("~/Downloads")
        self.output_dir = os.path.abspath(os.path.expanduser(output_dir)) if output_dir else default_dir
        self.cookies_browser = cookies_browser
        self.cookies_file = cookies_file
        self.impersonate = impersonate
        
        os.makedirs(self.output_dir, exist_ok=True)
        self.js_runtime, _ = check_js_runtime()
        self.has_ffmpeg = check_ffmpeg()

    def _build_options(self) -> dict:
        opts = {
            "quiet": True,
            "no_warnings": True,
            "noprogress": True,
            "overwrites": True,
            "logger": DownloaderLogger(),
            "outtmpl": os.path.join(self.output_dir, "%(title).150B [%(id)s] [%(resolution)s].%(ext)s"),
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

        # Enable TLS impersonation for Cloudflare bypass if curl_cffi is available
        if HAS_CURL_CFFI:
            target_client = self.impersonate or "chrome"
            try:
                opts["impersonate"] = ImpersonateTarget(client=target_client)
            except Exception:
                pass

        if self.cookies_browser in ("zen", "zen-browser"):
            zen_profile = find_zen_browser_profile()
            if zen_profile:
                opts["cookiesfrombrowser"] = ("firefox", zen_profile, None, None)
            else:
                print("[Warning] Could not find Zen Browser profile directory.")
        elif self.cookies_browser:
            opts["cookiesfrombrowser"] = (self.cookies_browser, None, None, None)
        elif self.cookies_file and os.path.isfile(self.cookies_file):
            opts["cookiefile"] = self.cookies_file

        return opts

    def _print_error_tips(self, err_msg: str):
        lowered = err_msg.lower()
        if "cloudflare" in lowered or "anti-bot" in lowered or "impersonat" in lowered:
            print("\n[Tip for Cloudflare anti-bot challenge]")
            if not HAS_CURL_CFFI:
                print("  1. Linux/PC: Install curl-cffi to bypass Cloudflare TLS checks:")
                print("     pip install curl-cffi")
            print("  2. iSH on iOS: Open the video link in your browser to pass Cloudflare,")
            print("     then pass cookies with: --cookies chrome (or --cookies-file cookies.txt)")
        elif "login" in lowered or "bot" in lowered:
            print("Tip: If the video is restricted or requires login, try: --cookies chrome")

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
            self._print_error_tips(err_msg)
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
            opts["outtmpl"] = os.path.join(self.output_dir, "%(title).150B [%(id)s] [audio].%(ext)s")
            opts["postprocessors"] = [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ]
        elif format_id:
            opts["format"] = f"{format_id}+bestaudio/best/{format_id}"
            opts["outtmpl"] = os.path.join(self.output_dir, f"%(title).150B [%(id)s] [{format_id}].%(ext)s")
            if self.has_ffmpeg:
                opts["merge_output_format"] = "mp4"
        elif height:
            opts["format"] = (
                f"bestvideo[height<={height}][ext=mp4]+bestaudio[ext=m4a]/"
                f"bestvideo[height<={height}]+bestaudio/"
                f"best[height<={height}][ext=mp4]/"
                f"best[height<={height}]/best"
            )
            opts["outtmpl"] = os.path.join(self.output_dir, f"%(title).150B [%(id)s] [{height}p].%(ext)s")
            if self.has_ffmpeg:
                opts["merge_output_format"] = "mp4"
        else:
            opts["format"] = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best"
            opts["outtmpl"] = os.path.join(self.output_dir, "%(title).150B [%(id)s] [%(resolution)s].%(ext)s")
            if self.has_ffmpeg:
                opts["merge_output_format"] = "mp4"

        last_update_time = 0.0

        def progress_hook(d):
            nonlocal last_update_time
            status = d.get("status")
            info_dict = d.get("info_dict", {})
            vcodec = info_dict.get("vcodec")
            acodec = info_dict.get("acodec")
            
            if audio_only or (vcodec == "none" and acodec and acodec != "none"):
                prefix = "[Audio]"
            elif acodec == "none" and vcodec and vcodec != "none":
                prefix = "[Video]"
            else:
                prefix = "[Media]"

            bar_len = 16
            total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0

            if status == "downloading":
                now = time.time()
                downloaded = d.get("downloaded_bytes", 0)
                if (now - last_update_time < 0.1) and (downloaded < total):
                    return
                last_update_time = now

                speed = d.get("speed") or 0
                eta = d.get("eta")

                pct = f"{(downloaded / total * 100):5.1f}%" if total else " N/A "
                dl_mb = f"{downloaded / (1024 * 1024):.1f}"
                tot_mb = f"{total / (1024 * 1024):.1f}M" if total else "N/A"
                spd_mb = f"{speed / (1024 * 1024):.1f}M/s" if speed else "N/A"
                eta_s = f"{int(eta)}s" if eta is not None else "N/A"

                if total:
                    filled = min(bar_len, int(bar_len * downloaded / total))
                    arrow = ">" if filled < bar_len else ""
                    bar = "=" * filled + arrow + " " * (bar_len - filled - len(arrow))
                else:
                    bar = " " * bar_len

                line = f"\r{prefix} [{bar}] {pct} | {dl_mb}/{tot_mb} | {spd_mb:>8} | ETA {eta_s:>3}"
                sys.stdout.write(f"{line}\033[K")
                sys.stdout.flush()

            elif status == "finished":
                tot_mb = f"{total / (1024 * 1024):.1f}M" if total else ""
                sys.stdout.write(f"\r{prefix} [{'=' * bar_len}] 100.0% | {tot_mb} | Done\033[K\n")
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
            err_msg = str(e)
            print(f"\n[Error] Download failed: {err_msg}")
            self._print_error_tips(err_msg)
            return None
        except Exception as e:
            print(f"\n[Error] Unexpected error during download: {e}")
            return None
