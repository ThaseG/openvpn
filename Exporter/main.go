package main

import (
	"flag"
	"net/http"
	"os"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/log/level"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"gopkg.in/yaml.v2"
)

var (
	version   = "1.0.0"
	buildDate = "unknown"
)

func main() {
	var (
		listenAddress = flag.String("web.listen-address", ":9234", "Address to listen on for web interface and telemetry")
		configFile    = flag.String("config.file", "config.yml", "Path to configuration file")
	)
	flag.Parse()

	// Setup logger
	logger := log.NewLogfmtLogger(log.NewSyncWriter(os.Stderr))
	logger = log.With(logger, "ts", log.DefaultTimestampUTC)
	logger = log.With(logger, "caller", log.DefaultCaller)

	level.Info(logger).Log("msg", "Starting OpenVPN Exporter", "version", version, "build_date", buildDate)

	// Load configuration
	conf, err := loadConfig(*configFile)
	if err != nil {
		level.Error(logger).Log("msg", "Error loading config", "err", err)
		os.Exit(1)
	}

	// Register collector
	collector := &OpenVPNCollector{
		conf:   conf,
		logger: logger,
	}
	prometheus.MustRegister(collector)

	// Create separate registries for different metrics
	ovpnRegistry := prometheus.NewRegistry()
	ovpnRegistry.MustRegister(collector)

	// Setup HTTP handlers
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		indexHandler(w, r, logger)
	})
	
	// /metrics - Only OpenVPN metrics (custom collector)
	http.Handle("/metrics", promhttp.HandlerFor(ovpnRegistry, promhttp.HandlerOpts{}))
	
	// /prom - Internal Go and process metrics (default registry)
	http.Handle("/prom", promhttp.Handler())
	
	http.HandleFunc("/static", func(w http.ResponseWriter, r *http.Request) {
		staticHandler(w, r, conf, logger)
	})
	
	http.HandleFunc("/sessions_local", func(w http.ResponseWriter, r *http.Request) {
		sessionsHandler(w, r, conf, logger)
	})

	level.Info(logger).Log("msg", "Listening on", "address", *listenAddress)
	if err := http.ListenAndServe(*listenAddress, nil); err != nil {
		level.Error(logger).Log("msg", "Error starting HTTP server", "err", err)
		os.Exit(1)
	}
}

func loadConfig(filename string) (*Config, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var conf Config
	if err := yaml.Unmarshal(data, &conf); err != nil {
		return nil, err
	}

	return &conf, nil
}

func indexHandler(w http.ResponseWriter, r *http.Request, logger log.Logger) {
	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenVPN Exporter</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            padding: 50px;
            max-width: 600px;
            width: 100%;
        }
        
        h1 {
            color: #333;
            font-size: 2.5em;
            margin-bottom: 10px;
            text-align: center;
        }
        
        .subtitle {
            color: #666;
            text-align: center;
            margin-bottom: 40px;
            font-size: 1.1em;
        }
        
        .links {
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        
        .link-item {
            display: block;
            padding: 18px 25px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 12px;
            transition: all 0.3s ease;
            font-weight: 500;
            font-size: 1.1em;
            text-align: center;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
        }
        
        .link-item:hover {
            transform: translateY(-3px);
            box-shadow: 0 6px 20px rgba(102, 126, 234, 0.6);
        }
        
        .link-item:active {
            transform: translateY(-1px);
        }
        
        .section-title {
            color: #888;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-top: 30px;
            margin-bottom: 15px;
            font-weight: 600;
        }
        
        .footer {
            margin-top: 40px;
            text-align: center;
            color: #999;
            font-size: 0.9em;
        }
        
        @media (max-width: 600px) {
            .container {
                padding: 30px 20px;
            }
            
            h1 {
                font-size: 2em;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 OpenVPN Exporter</h1>
        <p class="subtitle">Monitoring Dashboard</p>
        
        <div class="links">
            <div class="section-title">Metrics</div>
            <a href="/metrics" class="link-item">📊 Exporter Metrics</a>
            <a href="/prom" class="link-item">⚙️ Internal Exporter Metrics</a>
            
            <div class="section-title">Clients & Sessions</div>
            <a href="/static" class="link-item">👥 Local Clients</a>
            <a href="/sessions_local" class="link-item">📋 Local Sessions JSON</a>
        </div>
        
        <div class="footer">
            OpenVPN Exporter v1.0.0
        </div>
    </div>
</body>
</html>`
	
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(html))
}