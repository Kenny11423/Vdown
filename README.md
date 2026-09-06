**VDownloader CLI**  
A simple and lightweight CLI tool to download videos and audio from YouTube, YouTube Shorts, Facebook Reels, TikTok, Instagram, Twitter/X,...  
![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAnEAAAACCAYAAAA3pIp+AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAANklEQVR4nO3OYQ1AABSAwc8mi5wvkwZyCKCAACr4Z7a7BLfMzFYdAQDwF+da3dX+9QQAgNeuB6feBdUJcyS2AAAAAElFTkSuQmCC)  
**Features**  
- **Format Selection**: Quickly choose between  **MP4 (Video)** or  **MP3 (Audio)**.  
- **Dynamic Quality List**: Automatically queries the source video and lists all available resolutions (e.g. 1080p, 720p, 480p, 360p, or vertical equivalents for Shorts/Reels).  
- **Supports All Major Platforms**: YouTube, Shorts, Facebook Reels, TikTok, Instagram, Twitter/X, and more.  
- **Cookies Support**: Pass cookies from browsers (e.g. Chrome, Firefox) for private or restricted Facebook Reels / Instagram videos.  
- **Clean Terminal Progress**: Simple, lightweight, single-line progress indicator.  
![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAnEAAAACCAYAAAA3pIp+AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAANUlEQVR4nO3OMQ2AABAAsSNBCUrfD6LYGNDAgAU2QtIq6DIzW7UHAMBfHGt1V+fXEwAAXrseHDAF/orRG+cAAAAASUVORK5CYII=)  
**Quick Start**  
**1. Installation**  
cd "vdown"  
 ./setup.sh  
   
This creates a virtual environment, installs dependencies, and links vdown to ~/.local/bin/vdown so you can use it globally.  
![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAnEAAAACCAYAAAA3pIp+AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAM0lEQVR4nO3OUQmAQBBAwSdcjsu6HYxoDsEK/okwk2COmdnVGQAAf3GtalX76wkAAK/dDxFWBDkFf6+SAAAAAElFTkSuQmCC)  
**Usage**  
**Simple Usage**  
Simply run:  
vdown "https://www.youtube.com/watch?v=..."  
   
   
**Interactive Flow**  
When you run vdown "<url>", the CLI will display:  
1. Video Title, Platform, Duration, and Uploader.  
2. Prompt to choose **MP4** or  **MP3**:  
3. Select format:  
   [1] MP4 (Video)  
   [2] MP3 (Audio)  
 Choice [1-2] (default 1):  
   
4. If **MP4** is selected, it lists all available video qualities from the source:  
5. Available video qualities:  
   [1] Best available (recommended)  
   [2] 1080p (1920x1080) (~111.1 MB)  
   [3] 720p (1280x720) (~40.0 MB)  
   [4] 480p (854x480) (~27.1 MB)  
   [5] 360p (640x360) (~17.4 MB)  
   [6] 240p (426x240) (~7.5 MB)  
   [7] 144p (256x144) (~3.4 MB)  
 Choice [1-7] (default 1):  
   
6. If **MP3** is selected, it directly downloads and extracts high quality MP3 audio.  
![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAnEAAAACCAYAAAA3pIp+AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAM0lEQVR4nO3OMQ0AIAwAwZIgBKm1gjSMNCwYYCIkd9OP3zJzRMQMAAB+sfqJeroBAMCN2pTWBSSZVtjzAAAAAElFTkSuQmCC)  
**Command Line Options**  
| | |  
|-|-|  
| **Option** | **Description** |   
| url | The video URL to download |   
| -a, --audio, --mp3 | Download audio as MP3 directly without prompt |   
| -q, --quality <res> | Target video quality directly (e.g. 1080, 720, 480, best) |   
| `-o`, `--output <dir>` | Output folder (default: `~/Downloads`) |   
| -y, --yes | Skip prompts and download best MP4 automatically |   
| --cookies <browser> | Read cookies from browser (chrome, firefox, edge, brave) |   
| -i, --info | Display video details and available resolutions without downloading |   
| -h, --help | Show help message |   
   
![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAnEAAAACCAYAAAA3pIp+AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAANUlEQVR4nO3OMQ2AABAAsSNhwgJGkPcrHpnRgQU2QtIq6DIze3UGAMBf3Gu1VcfXEwAAXrseaJkELjbMzy0AAAAASUVORK5CYII=)  
**Examples**  
- **Direct MP3 download**:  
- vdown "https://www.youtube.com/watch?v=..." -a  
   
- **Direct 1080p MP4 download**:  
- vdown "https://www.youtube.com/watch?v=..." -q 1080  
   
- **Save to specific folder**:  
- vdown "https://www.youtube.com/shorts/..." -o ~/Videos  
   
- **Download restricted / private Facebook Reel**:  
- vdown "https://www.facebook.com/reel/..." --cookies chrome  
   
