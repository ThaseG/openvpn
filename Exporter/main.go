package main

import (
	"net/http"
	"os"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/kit/log/level"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"gopkg.in/alecthomas/kingpin.v2"
)

var (
	listenAddress = kingpin.Flag("web.listen-address", "Address to listen on for web interface and telemetry.").Default(":9234").String()
	metricsPath   = kingpin.Flag("web.telemetry-path", "Path under which to expose metrics.").Default("/metrics").String()
	configFile    = kingpin.Flag("config.file", "Path to configuration file.").Default("../Server/exporter.yaml").String()
	version       = "1.0.0"
	buildDate     = "unknown"
)

func main() {
	kingpin.Version(version)
	kingpin.HelpFlag.Short('h')
	kingpin.Parse()

	logger := log.NewLogfmtLogger(log.NewSyncWriter(os.Stderr))
	logger = log.With(logger, "ts", log.DefaultTimestampUTC)
	logger = log.With(logger, "caller", log.DefaultCaller)

	level.Info(logger).Log("msg", "Starting OpenVPN Exporter", "version", version, "build_date", buildDate)

	// Load configuration
	conf, err := loadConfig(*configFile)
	if err != nil {
		level.Error(logger).Log("msg", "Failed to load configuration", "err", err)
		os.Exit(1)
	}

	conf.Version = version
	conf.BuildDate = buildDate

	// Create collector
	collector := &OpenVPNCollector{
		conf:   conf,
		logger: logger,
	}

	// Register collector
	prometheus.MustRegister(collector)

	// HTTP handlers
	http.HandleFunc("/sessions", func(w http.ResponseWriter, r *http.Request) {
		sessionsHandler(w, r, conf, logger)
	})

	http.Handle(*metricsPath, promhttp.Handler())
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`<html>
			<head><title>OpenVPN Exporter</title></head>
			<body>
			<h1>OpenVPN Exporter</h1>
			<p><a href='` + *metricsPath + `'>Metrics</a></p>
			<p><a href='/sessions'>Sessions (JSON)</a></p>
			</body>
			</html>`))
	})

	level.Info(logger).Log("msg", "Listening on", "address", *listenAddress)
	if err := http.ListenAndServe(*listenAddress, nil); err != nil {
		level.Error(logger).Log("msg", "Error starting HTTP server", "err", err)
		os.Exit(1)
	}
}