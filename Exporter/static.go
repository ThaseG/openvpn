package main

import (
	"fmt"
	"net/http"
	"strconv"

	"github.com/go-kit/log"
	"github.com/go-kit/log/level"
)

func staticHandler(w http.ResponseWriter, r *http.Request, conf *Config, logger log.Logger) {
	_ = level.Debug(logger).Log("task", "Generating static HTML page")

	sessions, err := getAllOpenVPNSessions("", conf, logger)
	if err != nil {
		w.WriteHeader(500)
		fmt.Fprintf(w, "Error: %s", err.Error())
		return
	}

	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenVPN Local Clients</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f7fa;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
        }
        
        .header h1 {
            font-size: 2em;
            margin-bottom: 10px;
        }
        
        .back-link {
            display: inline-block;
            color: white;
            text-decoration: none;
            margin-top: 10px;
            opacity: 0.9;
        }
        
        .back-link:hover {
            opacity: 1;
        }
        
        .stats {
            display: flex;
            gap: 20px;
            margin-bottom: 30px;
            flex-wrap: wrap;
        }
        
        .stat-card {
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            flex: 1;
            min-width: 200px;
        }
        
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        
        .stat-label {
            color: #666;
            margin-top: 5px;
        }
        
        .table-container {
            background: white;
            border-radius: 10px;
            overflow: hidden;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
        }
        
        th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        td {
            padding: 15px;
            border-bottom: 1px solid #f0f0f0;
        }
        
        tr:hover {
            background: #f8f9fa;
        }
        
        tr:last-child td {
            border-bottom: none;
        }
        
        .status {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
        }
        
        .status-established {
            background: #d4edda;
            color: #155724;
        }
        
        .protocol-badge {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 4px;
            font-size: 0.8em;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .protocol-tcp {
            background: #cfe2ff;
            color: #084298;
        }
        
        .protocol-udp {
            background: #f8d7da;
            color: #842029;
        }
        
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #666;
            font-size: 0.9em;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌐 OpenVPN Local Clients</h1>
        <p>Active VPN connections and statistics</p>
        <a href="/" class="back-link">← Back to Dashboard</a>
    </div>
    
    <div class="stats">
        <div class="stat-card">
            <div class="stat-value">` + strconv.Itoa(len(sessions)) + `</div>
            <div class="stat-label">Active Connections</div>
        </div>
    </div>
    
    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>Protocol</th>
                    <th>Remote ID (CN)</th>
                    <th>Remote Host</th>
                    <th>Remote Port</th>
                    <th>Tunnel IP</th>
                    <th>State</th>
                    <th>Established</th>
                    <th>Bytes In</th>
                    <th>Bytes Out</th>
                </tr>
            </thead>
            <tbody>`

	for _, session := range sessions {
		protocolClass := "protocol-tcp"
		if session.Protocol == "udp" {
			protocolClass = "protocol-udp"
		}

		bytesIn := formatBytes(session.BytesIn)
		bytesOut := formatBytes(session.BytesOut)

		html += fmt.Sprintf(`
                <tr>
                    <td><span class="protocol-badge %s">%s</span></td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td><span class="status status-established">%s</span></td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                </tr>`,
			protocolClass,
			session.Protocol,
			session.RemoteID,
			session.RemoteHost,
			session.RemotePort,
			session.RemoteTs,
			session.State,
			session.Established,
			bytesIn,
			bytesOut,
		)
	}

	html += `
            </tbody>
        </table>
    </div>
    
    <div class="footer">
        Showing ` + strconv.Itoa(len(sessions)) + ` active connection(s)
    </div>
</body>
</html>`

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(html))
}

func formatBytes(bytesStr string) string {
	bytes, err := strconv.ParseFloat(bytesStr, 64)
	if err != nil {
		return bytesStr
	}

	units := []string{"B", "KB", "MB", "GB", "TB"}
	unitIndex := 0

	for bytes >= 1024 && unitIndex < len(units)-1 {
		bytes /= 1024
		unitIndex++
	}

	return fmt.Sprintf("%.2f %s", bytes, units[unitIndex])
}