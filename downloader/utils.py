import os
import re
import shutil
from urllib.parse import urlparse


def is_valid_url(url: str) -> bool:
    """Check if the string is a valid HTTP/HTTPS URL."""
    if not url or not isinstance(url, str):
        return False
    url = url.strip()
    try:
        parsed = urlparse(url)
        return parsed.scheme in ("http", "https") and bool(parsed.netloc)
    except Exception:
        return False


def detect_platform(url: str) -> str:
    """Identify the media platform from the URL."""
    url_lower = url.lower()
    if "youtube.com/shorts" in url_lower or ("youtu.be" in url_lower and "shorts" in url_lower):
        return "YouTube Shorts"
    elif "youtube.com" in url_lower or "youtu.be" in url_lower:
        return "YouTube"
    elif "facebook.com/reel" in url_lower or "fb.watch" in url_lower or "/share/r/" in url_lower:
        return "Facebook Reel"
    elif "facebook.com" in url_lower or "fb.com" in url_lower:
        return "Facebook"
    elif "tiktok.com" in url_lower:
        return "TikTok"
    elif "instagram.com/reel" in url_lower:
        return "Instagram Reel"
    elif "instagram.com" in url_lower:
        return "Instagram"
    elif "twitter.com" in url_lower or "x.com" in url_lower:
        return "X (Twitter)"
    elif "threads.net" in url_lower:
        return "Threads"
    elif "reddit.com" in url_lower or "redd.it" in url_lower:
        return "Reddit"
    elif "vimeo.com" in url_lower:
        return "Vimeo"
    else:
        domain = urlparse(url).netloc.replace("www.", "")
        return domain if domain else "Web Video"


def format_duration(seconds: float | int | None) -> str:
    """Convert duration in seconds to HH:MM:SS or MM:SS."""
    if seconds is None or seconds < 0:
        return "N/A"
    seconds = int(round(seconds))
    hrs = seconds // 3600
    mins = (seconds % 3600) // 60
    secs = seconds % 60
    if hrs > 0:
        return f"{hrs:02d}:{mins:02d}:{secs:02d}"
    return f"{mins:02d}:{secs:02d}"


def format_size(bytes_val: float | int | None) -> str:
    """Format bytes to human readable string (KB, MB, GB)."""
    if bytes_val is None or bytes_val <= 0:
        return "N/A"
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if bytes_val < 1024.0:
            return f"{bytes_val:.1f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.1f} PB"


def check_ffmpeg() -> bool:
    """Check if ffmpeg is available in PATH."""
    return shutil.which("ffmpeg") is not None


def check_js_runtime() -> tuple[str | None, str | None]:
    """Check for an available JS runtime (node, deno, bun) for YouTube challenge solver."""
    for runtime in ["node", "deno", "bun"]:
        path = shutil.which(runtime)
        if path:
            return runtime, path
    return None, None


def find_zen_browser_profile() -> str | None:
    """Locate the active profile directory of Zen Browser (Firefox-based)."""
    home = os.path.expanduser("~")
    candidate_roots = [
        os.path.join(home, ".config", "zen"),
        os.path.join(home, ".zen"),
        os.path.join(home, ".var", "app", "app.zen_browser.zen", ".config", "zen"),
        os.path.join(home, ".var", "app", "app.zen_browser.zen", ".zen"),
        os.path.join(home, "Library", "Application Support", "zen"),
        os.path.join(home, "AppData", "Roaming", "zen"),
    ]

    for root in candidate_roots:
        if not os.path.isdir(root):
            continue
        profiles_ini = os.path.join(root, "profiles.ini")
        if os.path.isfile(profiles_ini):
            try:
                import configparser
                config = configparser.ConfigParser()
                config.read(profiles_ini)
                for sec in config.sections():
                    if sec.startswith("Install") and config.has_option(sec, "Default"):
                        rel_path = config.get(sec, "Default")
                        full_path = os.path.join(root, rel_path)
                        if os.path.isdir(full_path):
                            return full_path
                for sec in config.sections():
                    if sec.startswith("Profile") and config.get(sec, "Default", fallback="0") == "1":
                        rel_path = config.get(sec, "Path", fallback="")
                        is_rel = config.get(sec, "IsRelative", fallback="1") == "1"
                        full_path = os.path.join(root, rel_path) if is_rel else rel_path
                        if os.path.isdir(full_path):
                            return full_path
            except Exception:
                pass
        # Fallback: scan for any directory containing cookies.sqlite
        try:
            for item in os.listdir(root):
                sub = os.path.join(root, item)
                if os.path.isdir(sub) and os.path.isfile(os.path.join(sub, "cookies.sqlite")):
                    return sub
        except Exception:
            pass
    return None



def extract_available_qualities(info: dict) -> list[dict]:
    """
    Extract unique video qualities from the video formats.
    Returns a list of dictionaries with quality details.
    """
    formats = info.get("formats", [])
    video_formats = [f for f in formats if f.get("vcodec") != "none"]
    if not video_formats:
        video_formats = formats

    qualities = {}
    for f in video_formats:
        h = f.get("height")
        w = f.get("width")
        vcodec = f.get("vcodec", "")
        if vcodec == "none":
            continue

        note = (f.get("format_note") or "").strip()
        fid = f.get("format_id")
        size = f.get("filesize") or f.get("filesize_approx") or 0
        fps = f.get("fps")

        if h and w:
            std_res = min(w, h)
            key = (std_res, max(w, h))
        elif h:
            key = (h, 0)
        elif note:
            key = note.lower()
        elif fid:
            key = fid
        else:
            continue

        if key not in qualities:
            qualities[key] = {
                "height": h,
                "width": w,
                "note": note,
                "format_id": fid,
                "filesize": size,
                "fps": fps,
            }
        else:
            if size and not qualities[key]["filesize"]:
                qualities[key]["filesize"] = size
            if not qualities[key]["height"] and h:
                qualities[key]["height"] = h
                qualities[key]["width"] = w

    def sort_key(item):
        k, v = item
        if isinstance(k, tuple):
            return (k[0] or 0, k[1] or 0, v["filesize"] or 0)
        if str(k).lower() == "hd":
            return (720, 0, 0)
        if str(k).lower() == "sd":
            return (480, 0, 0)
        return (0, 0, v["filesize"] or 0)

    sorted_items = sorted(qualities.items(), key=sort_key, reverse=True)

    result = [
        {
            "label": "Best available (recommended)",
            "height": None,
            "format_id": None,
            "filesize": None,
        }
    ]

    for k, v in sorted_items:
        h = v["height"]
        w = v["width"]
        fps_str = f" @ {v['fps']}fps" if v.get("fps") and v["fps"] > 30 else ""
        
        size_str = ""
        if v["filesize"]:
            sz_mb = v["filesize"] / (1024 * 1024)
            size_str = f" (~{sz_mb:.1f} MB)"

        if h and w:
            if h > w:
                label = f"{w}p ({w}x{h} vertical{fps_str}){size_str}"
            else:
                label = f"{h}p ({w}x{h}{fps_str}){size_str}"
        elif h:
            label = f"{h}p{fps_str}{size_str}"
        elif v["note"]:
            label = f"{v['note'].upper()}{size_str}"
        else:
            label = f"Format {v['format_id']}{size_str}"

        result.append({
            "label": label,
            "height": h,
            "format_id": v["format_id"],
            "filesize": v["filesize"],
        })

    return result
