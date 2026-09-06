# VDownloader CLI

A lightweight command-line tool to download videos and audio from YouTube, YouTube Shorts, Facebook Reels, TikTok, Instagram, Twitter/X, and 1,000+ other websites.

Compatible with standard Linux distributions (Ubuntu, Debian, Arch, Fedora) and iSH (Alpine Linux on iOS).

---

## Features

- Format selection: Choose between MP4 (Video) and MP3 (Audio).
- Dynamic quality detection: Automatically queries the source video and lists all available resolutions (1080p, 720p, 480p, 360p, or vertical equivalents for Shorts/Reels).
- Default output location: Files are saved to `~/Downloads` (`/home/<user>/Downloads` on Linux, `/root/Downloads` on iSH).
- Platform support: YouTube, Shorts, Facebook Reels, TikTok, Instagram, Twitter/X, and more.
- Browser cookies: Support extracting cookies from browsers (`--cookies chrome/firefox`) for private or restricted Facebook Reels and Instagram posts.
- Lightweight progress: Minimal single-line terminal progress output.

---

## Installation

### Standard Linux (Ubuntu, Debian, Arch, Fedora)

1. Navigate to the project directory:
   ```bash
   cd "/home/kennysk/video downloader"
   ```

2. Run the setup script:
   ```bash
   ./setup.sh
   ```

   The script verifies dependencies (Python 3, FFmpeg, Node.js), creates a virtual environment, installs packages, and symlinks `vdown` to `~/.local/bin/vdown`.

### iSH on iOS (iPhone / iPad)

1. Open the iSH application.

2. Place the project directory in `/root/` (via `git clone` or copy using the iOS Files app to: `Files -> On My iPhone -> iSH -> root`).

3. Run the setup script:
   ```sh
   cd /root/"video downloader"
   ./setup.sh
   ```

   The script installs required Alpine packages (`python3`, `py3-pip`, `ffmpeg`, `nodejs`, `git`, `bash`), installs Python dependencies, and symlinks `vdown` to `/usr/local/bin/vdown`.

4. Accessing downloaded files on iOS:
   - Open the iOS Files app.
   - Navigate to: `On My iPhone -> iSH -> root -> Downloads`.
   - Tap Share -> Save Video to export files to the Photos camera roll.

---

## Usage

### Interactive Mode

Run `vdown` followed by the URL:

```bash
vdown "https://www.youtube.com/watch?v=..."
vdown "https://www.youtube.com/shorts/..."
vdown "https://www.facebook.com/reel/..."
```

Workflow:
1. Video metadata (Title, Platform, Duration, Uploader) is displayed.
2. Select output format:
   ```text
   Select format:
     [1] MP4 (Video)
     [2] MP3 (Audio)
   Choice [1-2] (default 1):
   ```
3. If MP4 is chosen, available source resolutions are listed:
   ```text
   Available video qualities:
     [1] Best available (recommended)
     [2] 1080p (1920x1080) (~111.1 MB)
     [3] 720p (1280x720) (~40.0 MB)
     [4] 480p (854x480) (~27.1 MB)
     [5] 360p (640x360) (~17.4 MB)
     [6] 240p (426x240) (~7.5 MB)
     [7] 144p (256x144) (~3.4 MB)
   Choice [1-7] (default 1):
   ```
4. If MP3 is chosen, audio is downloaded and converted to MP3.

---

## Command Options

| Option | Description |
| :--- | :--- |
| `url` | Video URL to download |
| `-a`, `--audio`, `--mp3` | Download audio as MP3 directly without prompts |
| `-q`, `--quality <res>` | Target video quality directly (e.g. `1080`, `720`, `480`, `best`) |
| `-o`, `--output <dir>` | Destination folder (default: `~/Downloads`) |
| `-y`, `--yes` | Skip prompts and download best MP4 automatically |
| `--cookies <browser>` | Read cookies from browser (`zen`, `firefox`, `chrome`, `edge`, `brave`) |
| `--impersonate <target>` | Client to impersonate to bypass Cloudflare anti-bot (`chrome`, `safari`) |
| `-i`, `--info` | Display video details and available qualities without downloading |
| `-h`, `--help` | Show command help |

---

## Examples

- Download with Zen Browser cookies (bypasses Cloudflare / login):
  ```bash
  vdown "https://..." --cookies zen
  ```

- Download MP3 audio directly:
  ```bash
  vdown "https://www.youtube.com/watch?v=..." -a
  ```

- Download 1080p video directly:
  ```bash
  vdown "https://www.youtube.com/watch?v=..." -q 1080
  ```

- Download to a custom folder:
  ```bash
  vdown "https://www.youtube.com/watch?v=..." -o ~/Videos
  ```

- Download restricted Facebook Reel with browser cookies:
  ```bash
  vdown "https://www.facebook.com/reel/..." --cookies zen
  ```

- Inspect available qualities without downloading:
  ```bash
  vdown "https://www.youtube.com/watch?v=..." -i
  ```
