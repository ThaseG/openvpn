# OpenVPN Exporter

Prometheus exporter for OpenVPN server metrics with JSON session API endpoint.

## Features

- **Prometheus Metrics**: Exposes OpenVPN session metrics in Prometheus format
- **JSON API**: Provides detailed session information via `/sessions` endpoint
- **Multi-Protocol Support**: Collects data from both TCP and UDP OpenVPN instances depends on `exporter.yaml` config
- **Flexible Configuration**: Use one or both status files

## Metrics Exposed

### Prometheus Metrics (`/metrics`)

- `probe_success` - OpenVPN status (1 = up, 0 = down) with version label
- `ovpn_info` - Software information (product, version)
- `ovpn_sessions_total` - Total number of active VPN sessions
- `ovpn_bytes_in_total` - Bytes received per client (labeled by client CN)
- `ovpn_bytes_out_total` - Bytes sent per client (labeled by client CN)

### JSON API (`/sessions`)

Returns detailed session information including:
- Server hostname
- Client remote IP and port
- Client certificate CN (Common Name)
- Virtual IP address assigned
- Connection state
- Bytes/packets in/out
- Session established time

## Prerequisites

### OpenVPN Server Configuration

Your OpenVPN server must be configured to generate a status file. Add this to your OpenVPN server config:

```
# For UDP status file
status /home/openvpn/logs/openvpn-udp-status
# For TCP status file
status /home/openvpn/logs/openvpn-tcp-status
status-version 3
```

The status file will be automatically updated by OpenVPN with current client connections.

## Installation

### Build from Source

```bash
# Clone the repository
git clone <your-repo-url>
cd Exporter

# Download dependencies
go mod download

# Build
go build -o openvpn-exporter

# Optional: Build with version info
go build -ldflags "-X main.version=1.0.0 -X main.buildDate=$(date -u +%Y-%m-%d)" -o openvpn-exporter
```

## Configuration

Create a `../Docker/exporter.yaml` file:

```yaml
# Path to OpenVPN status file/s
ovpntcpstatus: "/home/openvpn/logs/openvpn-tcp-status"
ovpnudpstatus: "/home/openvpn/logs/openvpn-udp-status"
```

## Usage

### Basic Usage

```bash
./openvpn-exporter
```

### With Custom Configuration

```bash
./openvpn-exporter --config.file=/etc/openvpn-exporter/config.yaml
```

### Command-line Options

```
  --web.listen-address=":9234"
      Address to listen on for web interface and telemetry
  
  --web.telemetry-path="/metrics"
      Path under which to expose metrics
  
  --config.file="config.yaml"
      Path to configuration file
  
  --help, -h
      Show help
  
  --version
      Show version information
```

## Endpoints

- `/` - Landing page with links
- `/metrics` - Prometheus metrics endpoint
- `/sessions` - JSON API with detailed session information

## Prometheus Configuration

Add this to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'openvpn'
    static_configs:
      - targets: ['localhost:9234']
```

## Example Outputs

### Prometheus Metrics

```
# HELP probe_success OpenVPN Status
# TYPE probe_success gauge
probe_success{version="2.6.15"} 1

# HELP ovpn_info Software info
# TYPE ovpn_info counter
ovpn_info{product="OpenVPN",version="2.6.15"} 1

# HELP ovpn_sessions_total Total number of active sessions
# TYPE ovpn_sessions_total gauge
ovpn_sessions_total 3

# HELP ovpn_bytes_in_total Total number of bytes received
# TYPE ovpn_bytes_in_total counter
ovpn_bytes_in_total{client="user1_tcp"} 1234567
ovpn_bytes_in_total{client="user2_udp"} 9876543

# HELP ovpn_bytes_out_total Total number of bytes sent
# TYPE ovpn_bytes_out_total counter
ovpn_bytes_out_total{client="user1_tcp"} 7654321
ovpn_bytes_out_total{client="user2_udp"} 3456789
```

### JSON Sessions API

```json
[
  {
    "server": "vpn-server-01",
    "protocol": "tcp",
    "p1uniqueid": "1234567890",
    "p2uniqueid": "123",
    "state": "ESTABLISHED",
    "remotehost": "203.0.113.45",
    "remoteport": "54321",
    "remoteid": "user1",
    "remotets": "10.8.0.6",
    "established": "2024-01-15 10:30:45",
    "bytesin": "1234567",
    "bytesout": "7654321",
    "packetsin": "0",
    "packetsout": "0"
  },
  {
    "server": "vpn-server-01",
    "protocol": "udp",
    "p1uniqueid": "9876543210",
    "p2uniqueid": "456",
    "state": "ESTABLISHED",
    "remotehost": "203.0.113.89",
    "remoteport": "12345",
    "remoteid": "user2",
    "remotets": "10.8.0.10",
    "established": "2024-01-15 11:15:22",
    "bytesin": "9876543",
    "bytesout": "3456789",
    "packetsin": "0",
    "packetsout": "0"
  }
]
```

## Security Considerations

1. **File Permissions**: Ensure the OpenVPN status file is readable by the exporter user
2. **Firewall**: Restrict access to port 9234 to authorized hosts only
3. **Sensitive Data**: The `/sessions` endpoint exposes client IPs and CNs - consider authentication

## Troubleshooting

### No metrics shown

- Check that at least one OpenVPN status file exists and is readable
- Verify the paths in `../Docker/config.yaml` are correct
- Ensure OpenVPN is configured with `status` directive
- Check logs: the exporter will warn if it can't read a status file but continue if at least one is available

### Only TCP or UDP sessions showing

- Verify both status files exist if you configured both
- Check file permissions on both status files
- Look at exporter logs for warnings about which file couldn't be read

### Permission denied

```bash
# Give read permission to the status files
sudo chmod 644 /home/openvpn/logs/openvpn-tcp-status
sudo chmod 644 /home/openvpn/logs/openvpn-udp-status

# Or add exporter user to openvpn group
sudo usermod -aG openvpn prometheus
```

### Status file format not recognized

This exporter expects OpenVPN status version 3 format. Ensure your OpenVPN config has:

```
status-version 3
```

## License

This project maintains compatibility with the original exporter format.

## Contributing

Contributions are welcome! Please submit pull requests or open issues for bugs and feature requests.