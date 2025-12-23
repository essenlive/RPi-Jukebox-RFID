# Phoniebox Service

This directory contains the Phoniebox application service for Balena deployment.

## Architecture

The Phoniebox Balena deployment uses a multi-service architecture:

```
┌─────────────────────────────────────────┐
│           Balena Device                 │
├─────────────────────────────────────────┤
│                                         │
│  ┌───────────────┐   ┌──────────────┐  │
│  │  phoniebox    │   │    audio     │  │
│  │   service     │──▶│   service    │  │
│  │               │   │  (balena)    │  │
│  │ - Web UI      │   │              │  │
│  │ - MPD         │   │ - PulseAudio │  │
│  │ - RFID        │   │ - Bluetooth  │  │
│  │ - Lighttpd    │   │ - ALSA       │  │
│  └───────────────┘   └──────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

## Services

### Phoniebox Service (this directory)

**Purpose:** Main application logic and user interface

**Components:**
- Lighttpd web server with PHP
- MPD (Music Player Daemon) for audio playback
- RFID reader daemon for card detection
- Python scripts for control logic

**Audio:** Connects to the `audio` service via PulseAudio TCP (port 4317)

**Data Volumes:**
- `phoniebox-data`: Audio files, playlists, RFID card mappings
- `mpd-data`: MPD database and state
- `phoniebox-logs`: Application logs

### Audio Service (Balena Audio Block)

**Purpose:** Centralized audio management

**Components:**
- PulseAudio server (TCP port 4317)
- Bluetooth audio support
- ALSA device management
- Automatic device detection

**Source:** [balenablocks/audio](https://github.com/balena-io-experimental/audio)

**Benefits:**
- Bluetooth pairing managed independently
- Automatic audio routing
- Multi-client support
- Volume normalization
- Device hotplugging

## Why This Architecture?

### Separation of Concerns
- **Audio service** handles all audio complexities (Bluetooth, ALSA, routing)
- **Phoniebox service** focuses on user interface and playback logic

### Easier Maintenance
- Audio updates don't require rebuilding Phoniebox
- Bluetooth issues isolated to audio service
- Clear service boundaries

### Reusability
- Audio service can be used by other services
- Standard Balena block with community support
- Well-tested audio stack

### Simplified Configuration
- No manual PulseAudio/Bluetooth setup
- Automatic device detection
- Standard environment variables

## Configuration

### Environment Variables

**Phoniebox Service:**
- `PULSE_SERVER`: PulseAudio server address (default: `tcp:audio:4317`)
- `JUKEBOX_HOME_DIR`: Application directory (default: `/home/phoniebox/RPi-Jukebox-RFID`)

**Audio Service:**
- `AUDIO_OUTPUT`: Output device (default: `AUTO`)
  - `AUTO`: Automatic detection
  - `<device>`: Specific ALSA device
- `AUDIO_LOG_LEVEL`: Logging level (default: `info`)

### Bluetooth Pairing

Bluetooth is managed by the audio service:

```bash
# SSH into the audio service
balena ssh <device-uuid> audio

# Use bluetoothctl
bluetoothctl
scan on
pair AA:BB:CC:DD:EE:FF
trust AA:BB:CC:DD:EE:FF
connect AA:BB:CC:DD:EE:FF
```

## Development

### Building Locally

```bash
# Build phoniebox service
docker build -t phoniebox -f phoniebox/Dockerfile.template .

# Test with docker-compose
docker-compose up
```

### Logs

```bash
# View phoniebox logs
balena logs <device-uuid> phoniebox

# View audio logs
balena logs <device-uuid> audio
```

## Files

- `Dockerfile.template`: Multi-arch Dockerfile for Phoniebox
- `balena-start.sh`: Container startup script
- `README.md`: This file

## Dependencies

**Build Time:**
- Python 3
- PHP
- GCC toolchain
- Various libraries (see Dockerfile)

**Runtime:**
- MPD (Music Player Daemon)
- Lighttpd web server
- PulseAudio client libraries
- ALSA utilities

**External Services:**
- `audio` service (PulseAudio server on port 4317)
