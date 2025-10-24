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

	_ = level.Info(logger).Log("msg", "Starting OpenVPN Exporter", "version", version, "build_date", buildDate)

	// Load configuration
	conf, err := loadConfig(*configFile)
	if err != nil {
		_ = level.Error(logger).Log("msg", "Error loading config", "err", err)
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

	_ = level.Info(logger).Log("msg", "Listening on", "address", *listenAddress)
	if err := http.ListenAndServe(*listenAddress, nil); err != nil {
		_ = level.Error(logger).Log("msg", "Error starting HTTP server", "err", err)
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
