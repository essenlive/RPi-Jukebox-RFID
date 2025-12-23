#!/bin/bash
# Balena startup script for Phoniebox
# Audio is handled by the separate audio service

set -e

echo "Starting Phoniebox on Balena..."

# Set up environment
export JUKEBOX_HOME_DIR=${JUKEBOX_HOME_DIR:-/home/phoniebox/RPi-Jukebox-RFID}
export PATH=$PATH:$JUKEBOX_HOME_DIR/scripts
export PULSE_SERVER=${PULSE_SERVER:-tcp:audio:4317}

# Create necessary directories if they don't exist
mkdir -p ${JUKEBOX_HOME_DIR}/shared/audiofolders
mkdir -p ${JUKEBOX_HOME_DIR}/shared/playlists
mkdir -p ${JUKEBOX_HOME_DIR}/shared/shortcuts
mkdir -p ${JUKEBOX_HOME_DIR}/logs
mkdir -p /var/lib/mpd/music
mkdir -p /var/lib/mpd/playlists

# Link audio folders for MPD
if [ ! -L /var/lib/mpd/music/audiofolders ]; then
    ln -sf ${JUKEBOX_HOME_DIR}/shared/audiofolders /var/lib/mpd/music/audiofolders
fi

# Wait for audio service to be ready
echo "Waiting for audio service..."
for i in {1..30}; do
    if pactl info &>/dev/null; then
        echo "Audio service is ready!"
        break
    fi
    echo "Waiting for PulseAudio... ($i/30)"
    sleep 2
done

# Configure MPD with PulseAudio output
cat > /etc/mpd.conf <<EOF
music_directory "/var/lib/mpd/music"
playlist_directory "/var/lib/mpd/playlists"
db_file "/var/lib/mpd/tag_cache"
log_file "/var/log/mpd/mpd.log"
pid_file "/run/mpd/pid"
state_file "/var/lib/mpd/state"
sticker_file "/var/lib/mpd/sticker.sql"

bind_to_address "0.0.0.0"
port "6600"

# Use PulseAudio from audio service
audio_output {
    type "pulse"
    name "Balena Audio"
    server "${PULSE_SERVER}"
    mixer_type "software"
}
EOF

# Start MPD
mkdir -p /var/log/mpd /run/mpd
chown mpd:audio /var/log/mpd /run/mpd
echo "Starting MPD..."
mpd /etc/mpd.conf || echo "MPD already running or failed to start"

# Configure Lighttpd
cat > /etc/lighttpd/lighttpd.conf <<EOF
server.modules = (
    "mod_indexfile",
    "mod_access",
    "mod_alias",
    "mod_redirect",
    "mod_fastcgi",
)

server.document-root = "/var/www/html"
server.upload-dirs = ( "/var/cache/lighttpd/uploads" )
server.errorlog = "/var/log/lighttpd/error.log"
server.pid-file = "/run/lighttpd.pid"

index-file.names = ( "index.php", "index.html" )

mimetype.assign = (
  ".html" => "text/html",
  ".txt" => "text/plain",
  ".jpg" => "image/jpeg",
  ".png" => "image/png",
  ".css" => "text/css",
  ".js" => "application/javascript"
)

fastcgi.server = ( ".php" =>
  ((
    "bin-path" => "/usr/bin/php-cgi",
    "socket" => "/run/lighttpd/php.socket",
    "max-procs" => 1,
    "bin-environment" => (
      "PHP_FCGI_CHILDREN" => "4",
      "PHP_FCGI_MAX_REQUESTS" => "10000"
    ),
    "bin-copy-environment" => (
      "PATH", "SHELL", "USER"
    ),
    "broken-scriptfilename" => "enable"
  ))
)
EOF

# Create upload directory
mkdir -p /var/cache/lighttpd/uploads /var/log/lighttpd /run/lighttpd
chown -R www-data:www-data /var/cache/lighttpd /var/log/lighttpd /run/lighttpd
chmod 755 /var/cache/lighttpd/uploads

# Start Lighttpd
echo "Starting Lighttpd web server..."
lighttpd -f /etc/lighttpd/lighttpd.conf &

# Wait for MPD to be ready
echo "Waiting for MPD to be ready..."
sleep 2
mpc update || echo "MPD update failed, continuing..."

# Start RFID reader daemon
echo "Starting RFID reader daemon..."
cd ${JUKEBOX_HOME_DIR}/scripts
python3 daemon_rfid_reader.py &

# Keep container running and monitor services
echo "Phoniebox started successfully!"
echo "Web interface available at http://[device-ip]"
echo "Audio is managed by the 'audio' service"

# Monitor and restart services if they crash
while true; do
    sleep 30

    # Check if lighttpd is running
    if ! pgrep -x lighttpd > /dev/null; then
        echo "Lighttpd died, restarting..."
        lighttpd -f /etc/lighttpd/lighttpd.conf &
    fi

    # Check if MPD is running
    if ! pgrep -x mpd > /dev/null; then
        echo "MPD died, restarting..."
        mpd /etc/mpd.conf &
    fi

    # Check if RFID daemon is running
    if ! pgrep -f daemon_rfid_reader.py > /dev/null; then
        echo "RFID daemon died, restarting..."
        cd ${JUKEBOX_HOME_DIR}/scripts
        python3 daemon_rfid_reader.py &
    fi
done
