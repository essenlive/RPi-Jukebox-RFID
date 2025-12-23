# Phoniebox Balena Deployment Guide

This guide explains how to deploy the Phoniebox (RPi-Jukebox-RFID) project to Balena Cloud for easy management and deployment to Raspberry Pi devices.

## Architecture

The Phoniebox Balena deployment uses a modern multi-service architecture:

```
┌──────────────────────────────────────────────┐
│            Balena Device                     │
├──────────────────────────────────────────────┤
│                                              │
│  ┌──────────────┐       ┌─────────────────┐ │
│  │  phoniebox   │       │     audio       │ │
│  │   service    │──────▶│    service      │ │
│  │              │ TCP   │   (balena)      │ │
│  │ - Web UI     │ 4317  │                 │ │
│  │ - MPD        │       │ - PulseAudio    │ │
│  │ - RFID       │       │ - Bluetooth     │ │
│  │ - Lighttpd   │       │ - ALSA          │ │
│  └──────────────┘       └─────────────────┘ │
│                                              │
└──────────────────────────────────────────────┘
```

### Services

**Phoniebox Service (`./phoniebox/`):**
- Main application logic and web interface
- MPD for music playback control
- RFID reader daemon
- Connects to audio service via PulseAudio

**Audio Service ([balenablocks/audio](https://github.com/balena-io-experimental/audio)):**
- Centralized audio management
- Bluetooth pairing and connectivity
- ALSA device management
- PulseAudio server (TCP port 4317)

**Benefits:**
- Cleaner separation of concerns
- Audio updates don't require rebuilding Phoniebox
- Standard, well-tested audio block
- Easier Bluetooth management
- Multi-client audio support

## Prerequisites

1. A [Balena Cloud](https://www.balena.io/) account (free tier available)
2. [Balena CLI](https://github.com/balena-io/balena-cli) installed on your computer
3. A Raspberry Pi (any model: Pi 1, 2, 3, 4, Zero, etc.)
4. An SD card (8GB or larger recommended)
5. RFID reader hardware compatible with the Phoniebox

## Quick Start

### 1. Install Balena CLI

```bash
# On Linux/macOS
npm install -g balena-cli

# Or download from: https://github.com/balena-io/balena-cli/releases
```

### 2. Login to Balena

```bash
balena login
```

### 3. Create a Balena Application

```bash
balena app create phoniebox --type raspberry-pi4
```

Replace `raspberry-pi4` with your device type:
- `raspberry-pi` (Raspberry Pi 1)
- `raspberry-pi2`
- `raspberry-pi3`
- `raspberry-pi4`
- `raspberrypi3-64` (64-bit OS)
- `raspberrypi4-64` (64-bit OS)

### 4. Add Your Device

1. Go to your Balena dashboard: https://dashboard.balena-cloud.com/
2. Click on your "phoniebox" application
3. Click "Add device"
4. Download the OS image
5. Flash the image to your SD card using [Balena Etcher](https://www.balena.io/etcher/)

### 5. Deploy the Application

From the Phoniebox repository root:

```bash
balena push phoniebox
```

This will build the Docker container and deploy it to all devices in your fleet.

## Configuration

### Environment Variables

You can set these in the Balena dashboard under "Device Variables" or "Fleet Variables":

- `JUKEBOX_HOME_DIR`: Home directory for Phoniebox (default: `/home/phoniebox/RPi-Jukebox-RFID`)
- `TZ`: Timezone (default: `Europe/Berlin`)

### Device Configuration

The following device configurations are automatically set:

- `BALENA_HOST_CONFIG_gpu_mem`: `16` (minimal GPU memory)
- `BALENA_HOST_CONFIG_dtparam`: `audio=on,spi=on` (enable audio and SPI)

You can modify these in the Balena dashboard under "Device Configuration".

## Hardware Setup

### RFID Readers

The following RFID readers are supported:

1. **USB RFID Reader** - Plug and play, no additional configuration needed
2. **RC522** (SPI) - Requires SPI enabled (already configured in balena.yml)
3. **PN532** (SPI/I2C) - Requires appropriate interface enabled

### Audio Output

Connect speakers or headphones to:
- 3.5mm audio jack
- HDMI (if using a monitor/TV)
- USB sound card
- HAT audio boards (HiFiBerry, etc.)
- **Bluetooth speakers/headphones** (fully supported!)

### Bluetooth Audio

Bluetooth audio is managed by the dedicated **audio service**. This service handles all Bluetooth pairing, connectivity, and audio routing automatically.

**How it works:**
1. Bluetooth is managed by the `audio` service
2. PulseAudio (in audio service) handles all audio routing
3. Phoniebox connects via PulseAudio TCP (port 4317)
4. Audio automatically switches when Bluetooth devices connect

**Pairing a Bluetooth device:**

1. SSH into the **audio service** (not phoniebox):
   ```bash
   balena ssh <device-uuid> audio
   ```

2. Use bluetoothctl to pair:
   ```bash
   bluetoothctl
   scan on
   # Wait for your device to appear
   pair AA:BB:CC:DD:EE:FF
   trust AA:BB:CC:DD:EE:FF
   connect AA:BB:CC:DD:EE:FF
   exit
   ```

3. The device will auto-reconnect when powered on

**Configuration via Environment Variables:**

Set these in the Balena dashboard for the `audio` service:

- `AUDIO_OUTPUT`: Output device (default: `AUTO`)
  - `AUTO`: Automatic detection (recommended)
  - Specific device name for fixed output

**Troubleshooting Bluetooth:**

```bash
# SSH into audio service
balena ssh <device-uuid> audio

# Check Bluetooth status
bluetoothctl show

# Check paired devices
bluetoothctl devices

# Check PulseAudio sinks
pactl list sinks short

# Check audio service logs
balena logs <device-uuid> audio --tail
```

**Advanced: Multi-room audio**

The balena audio block supports multi-room audio. Multiple Phoniebox devices can connect to the same audio service. See the [balena-audio documentation](https://github.com/balena-io-experimental/audio) for details.

### GPIO Buttons (Optional)

If using GPIO buttons for control, they will be automatically detected if configured in the Phoniebox settings.

## Accessing the Web Interface

Once deployed, you can access the Phoniebox web interface at:

```
http://<device-ip-address>
```

You can find your device's IP address in the Balena dashboard.

## Data Persistence

The following data is persisted across container updates:

- `/home/phoniebox/RPi-Jukebox-RFID/shared` - Audio files, playlists, RFID mappings
- `/var/lib/mpd` - MPD database and playlists
- `/home/phoniebox/RPi-Jukebox-RFID/logs` - Application logs

## Uploading Audio Files

### Option 1: Via Samba (Not enabled by default in container)

You can enable Samba by modifying the `balena-start.sh` script.

### Option 2: Via Web Interface

1. Access the web interface
2. Navigate to "Manage Files & Folders"
3. Upload audio files directly

### Option 3: Via Balena CLI

```bash
# Copy files to the running container
balena ssh <device-uuid>
# Then use scp or other tools to transfer files
```

## Troubleshooting

### View Logs

The deployment has two services: `phoniebox` and `audio`. You can view logs for each:

```bash
# View phoniebox service logs
balena logs <device-uuid> phoniebox

# View audio service logs
balena logs <device-uuid> audio

# View all services logs
balena logs <device-uuid>

# Follow logs in real-time
balena logs <device-uuid> phoniebox --tail
balena logs <device-uuid> audio --tail
```

### SSH into Services

```bash
# SSH into phoniebox service
balena ssh <device-uuid> phoniebox

# SSH into audio service (for Bluetooth management)
balena ssh <device-uuid> audio

# SSH into host OS
balena ssh <device-uuid>
```

### Restart Services

Services automatically restart if they crash. To manually restart:

```bash
balena restart <device-uuid>
```

### RFID Reader Not Detected

1. Check if the reader is properly connected
2. For USB readers, check `lsusb` output
3. For SPI readers (RC522, PN532), ensure SPI is enabled in device configuration

### No Audio Output

1. Check audio device: `aplay -l`
2. Test audio: `speaker-test -c2`
3. Adjust volume: `amixer set Master 75%`

## Updating the Application

To deploy updates:

```bash
git pull  # Get latest changes
balena push phoniebox
```

Balena will automatically build and deploy to all devices in your fleet with zero downtime.

## Advanced Configuration

### Multiple Devices

You can deploy to multiple Raspberry Pis simultaneously. All devices in your "phoniebox" fleet will receive the same code and configuration.

### Device-Specific Settings

Use "Device Variables" in the Balena dashboard to configure individual devices differently.

### Custom Audio Configuration

Edit the MPD configuration in `balena-start.sh` to customize audio output settings.

## Features

### Enabled in Balena Deployment

- ✅ RFID card reading
- ✅ Web interface
- ✅ MPD audio playback
- ✅ Playlists and audio management
- ✅ **Bluetooth audio support** (speakers and headphones)
- ✅ GPIO support (for buttons and controls)
- ✅ SPI support (for RC522, PN532 readers)
- ✅ Automatic service recovery
- ✅ PulseAudio integration

### Limitations

- ⚠️ Samba file sharing disabled by default (can be enabled)
- ⚠️ WiFi hotspot mode not configured (use Balena WiFi management)
- ⚠️ Spotify support requires additional configuration

## Support

For issues specific to Balena deployment, please open an issue on the repository.

For general Phoniebox questions:
- [Phoniebox Wiki](https://github.com/MiczFlor/RPi-Jukebox-RFID/wiki)
- [GitHub Issues](https://github.com/MiczFlor/RPi-Jukebox-RFID/issues)
- [Matrix Community](https://matrix.to/#/#phoniebox_community:matrix.org)

## License

This Balena deployment configuration is part of the Phoniebox project and follows the same license terms.
