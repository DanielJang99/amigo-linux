# AMIGO testbed code

Code for managing the Amigo testbed described in the paper "A Worldwide Look Into Mobile Access Networks Through the Eyes of AmiGos" published at TMA2023: https://tma.ifip.org/2023/tma2023-program/

## Overview

This repository contains a Dockerized network monitoring testbed that continuously collects network performance data, executes remote commands from a control server, and reports detailed metrics about network quality, speed, latency, and Starlink-specific parameters.

## How to Run the Container

### Prerequisites

- Docker installed and running
- Docker registry access to `hsj276/amigo-linux-image:latest`
- Machine ID (automatically detected from `/etc/machine-id` on Linux)

### Quick Start

Using the provided script:

```bash
./start_container.sh [MACHINE_ID]
```

The script will:
1. Verify Docker installation and daemon status
2. Check registry access and pull the latest image
3. Obtain the machine ID from:
   - Command line argument (if provided)
   - `.machine-id` file (local)
   - `/etc/machine-id` (Linux system)
4. Start the container with required capabilities

### Manual Container Launch

```bash
MACHINE_ID=$(cat /etc/machine-id)
sudo docker run -d \
  -e HOST_MACHINE_ID=$MACHINE_ID \
  --platform linux/amd64 \
  --network host \
  --cap-add CAP_NET_ADMIN \
  hsj276/amigo-linux-image:latest
```

**Important Flags:**
- `-d`: Run in detached mode (background)
- `--network host`: Direct access to host network interfaces
- `--cap-add CAP_NET_ADMIN`: Network administration capabilities for testing
- `-e HOST_MACHINE_ID`: Device identification for data reporting

### Building the Image

```bash
cd container
docker build -t hsj276/amigo-linux-image:latest .
```


## Scripts Executed in the Container

### 1. Startup Script: `entrypoint.sh`

**Runs on container start**

Execution order:
1. Clones/updates repository from `https://github.com/DanielJang99/amigo-linux.git` to `/amigo-linux`
2. Installs Python dependencies from `requirements.txt`
3. Starts SSH service (port 22)
4. Starts cron service for scheduled jobs

### 2. Scheduled Jobs (Cron)

Defined in `container/cronjobs`:

| Schedule | Script | Purpose |
|----------|--------|---------|
| Every minute | `need-to-run.sh` | Monitor and start `state-update.sh` if needed |
| Daily @ 4 AM | `monitor_starlink_grpc_jobs.sh` | Monitor Starlink dish status and obstruction |
| Daily @ 5 AM | `stop_grpc_jobs.sh` | Stop Starlink gRPC monitoring jobs |
| Daily @ midnight | `stop-state-update.sh` | Stop state-update processes |

### 3. Main Monitoring Daemon: `state-update.sh`

**Long-running background process**

**Activities:**

**Status Reporting (every 5 minutes):**
- Reports to `https://mobile.batterylab.dev:8082/status` or `:8083/status`
- Sends comprehensive system state (see Data Collection section)

**Remote Command Execution (every 30 seconds):**
- Polls server for commands: `https://mobile.batterylab.dev:PORT/action`
- Executes commands with timeout and background options
- Reports completion status back to server

**Network Testing (every 1 hour):**
- Conditionally runs network tests if:
  - No other test is running
  - Device is connected
  - Data usage is below configured limits
- Executes `net-testing.sh` with current parameters

**Network Status Monitoring (every 1 minute):**
- Detects network type (WiFi, Docker, Ethernet)
- Retrieves public IP address
- Monitors WiFi SSID
- Tracks data usage per interface

### 4. Network Testing Suite: `net-testing.sh`

**Launched by `state-update.sh` every hour**

**Tests Performed:**

1. **DNS Test** (`run_dns_test`)
   - Target: `https://test.nextdns.io`
   - Output: `./results/dns-results/[DATE]/[TIMESTAMP].txt`

2. **MTR Traceroute** (`test_scripts/mtr.sh`)
   - Targets: google.com, facebook.com, amazon.com, 8.8.8.8, 1.1.1.1, etc.
   - Tests both IPv4 and IPv6 routes
   - Output: `./results/mtrlogs/[DATE]/[TIMESTAMP]/*.txt.gz`

3. **Speed Tests** (`test_scripts/speed-test.sh`)
   - **Ookla Speedtest CLI** - JSON output
   - **Cloudflare Speedtest** - Text output via Node.js CLI
   - Output: `./results/speedtest-cli-logs/[DATE]/[TIMESTAMP]/`

4. **CDN Performance** (`test_scripts/cdn-test.sh`)
   - Downloads test files from 7 CDN sources:
     - Cloudflare, Google, jsDelivr, Microsoft, jQuery CDN, Facebook
   - Metrics: DNS lookup, connection time, transfer time, download speed
   - Output: `./results/cdnlogs/[DATE]/[TIMESTAMP]/`

### 5. Location Logging: `run_location_logging.sh`

**Executed by `need-to-run.sh` every minute**

**Function:**
- Detects if device is on Starlink network (checks ASN 14593)
- If on Starlink, collects GPS location from dish via gRPC
- Runs: `python3 dish_grpc_text.py location -t 1 -O locationlogs/[DATE].txt`
- Appends location data to daily log file

### 6. Starlink Monitoring: `monitor_starlink_grpc_jobs.sh`

**Runs daily at 4 AM**

**Jobs:**

1. **Dish Status Monitoring**
   - Command: `python3 dish_grpc_text.py status -t 1 -O results/dish_status/[DATE].csv`
   - Collects: Signal strength, obstruction, uptime, download/upload speeds
   - Output: CSV format

2. **Obstruction Map**
   - Command: `python3 get_obstruction_raw.py results/obstruction_maps/ -t 1`
   - Collects: Visual obstruction data around dish
   - Output: Binary obstruction maps

## Data Collection

### Device Identification
- **Machine ID:** From `HOST_MACHINE_ID` environment variable
- **Source:** Linux `/etc/machine-id` or `.machine-id` file
- **Used for:** All server reports and data correlation

### Status Report Data (every 5 minutes)

Sent to `https://mobile.batterylab.dev:PORT/status`:

```json
{
  "vrs_num": "3.0",
  "today": "DD-MM-YYYY",
  "timestamp": "UNIX_SECONDS",
  "server_port": "8082 or 8083",
  "last_curl_dur": "SECONDS",
  "uid": "HOST_MACHINE_ID",
  "uptime": "SECONDS",
  "dish_location": "GPS_COORDINATES or NONE",
  "net_testing_proc": "COUNT",
  "def_iface": "INTERFACE_NAME",
  "public_ip": "X.X.X.X",
  "wifi_ssid": "NETWORK_NAME or NONE",
  "today_wifi_data": "BYTES",
  "today_docker_data": "BYTES",
  "network_type": "wifi/docker/ethernet_true/false"
}
```

### Network Performance Data (every 1 hour)

| Metric | Collection Method | Storage Location |
|--------|-------------------|------------------|
| **DNS Performance** | `test.nextdns.io` fetch | `results/dns-results/` |
| **Latency/Routes** | MTR to major hosts | `results/mtrlogs/` (compressed) |
| **Download Speed** | Ookla + Cloudflare speedtest | `results/speedtest-cli-logs/` |
| **CDN Performance** | curl to 7 CDN sources | `results/cdnlogs/` |
| **Starlink Status** | gRPC to dish (daily @ 4 AM) | `results/dish_status/` (CSV) |
| **Starlink Obstructions** | gRPC obstruction map (daily @ 4 AM) | `results/obstruction_maps/` |
| **Starlink Location** | gRPC to dish (every minute) | `locationlogs/` |

### Data Usage Monitoring

- **Tracked Interfaces:** All network interfaces via `/sys/class/net/*/statistics/`
- **Metrics:** RX/TX bytes per interface
- **Frequency:** Every minute
- **Purpose:** Enforce data usage limits and monitor consumption

## Configuration

### Config File: `docker-config.conf`

Controls data usage limits:

```
MAX_DOCKER_GB=1
MAX_WIFI_GB=10
```

Network testing pauses when these limits are exceeded.

### Control Files (in `linux/` directory)

| File | Purpose | Values |
|------|---------|--------|
| `.isDebug` | Debug mode flag | `true` or `false` |
| `.server_port` | Last used server port | `8082` or `8083` |
| `.status` | Control flag for state-update | `true` or `false` |
| `.last_report` | Timestamp of last status report | Unix timestamp |
| `.last_net` | Timestamp of last network test | Unix timestamp |
| `.net_status` | Enable/disable network testing | `true` or `false` |

### Server Endpoints

**Base URL:** `https://mobile.batterylab.dev`

1. **Status Report (POST):** `:{PORT}/status`
2. **Action Query (GET):** `:{PORT}/action?id=UID&prev_command=ID&termuxUser=USER`
3. **Command Completion (GET):** `:{PORT}/commandDone?id=UID&command_id=ID&status=CODE`

**Port Selection:** Randomly alternates between ports 8082 and 8083

## Log Files

- **State Update Logs:** `logs/[DATE]/log-state-update-[DATE]_[TIME].txt`
- **Network Testing Logs:** `logs/[DATE]/net-testing-[DATE]_[TIME].txt`
- **Location Logs:** `locationlogs/[DATE].txt`
- **Cron Logs:** `log-need-run`, `.log-starlink-grpc-monitor`
