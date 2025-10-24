package main

import (
	"net/http"
	"strconv"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/log/level"
	"github.com/prometheus/client_golang/prometheus"
)

type OpenVPNCollector struct {
	conf   *Config
	logger log.Logger
	// Removed unused req field
}

var (
	ovpnInfo          = prometheus.NewDesc("ovpn_info", "Software info", []string{"product", "version"}, nil)
	ovpnSessTotal     = prometheus.NewDesc("ovpn_sessions_total", "Total number of active sessions", nil, nil)
	ovpnBytesInTotal  = prometheus.NewDesc("ovpn_bytes_in_total", "Total number of bytes received", []string{"client"}, nil)
	ovpnBytesOutTotal = prometheus.NewDesc("ovpn_bytes_out_total", "Total number of bytes sent", []string{"client"}, nil)
	ovpnProbeSuccess  = prometheus.NewDesc("probe_success", "OpenVPN Status", []string{"version"}, nil)
)

// Implement prometheus.Collector Describe method
func (c *OpenVPNCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- ovpnProbeSuccess
	ch <- ovpnInfo
	ch <- ovpnSessTotal
	ch <- ovpnBytesInTotal
	ch <- ovpnBytesOutTotal
}

// Implement prometheus.Collector Collect method
func (c *OpenVPNCollector) Collect(ch chan<- prometheus.Metric) {
	_ = level.Debug(c.logger).Log("task", "Collecting OpenVPN metrics")

	var allSessions []SessionExport
	var products []string
	var versions []string

	// Collect TCP sessions
	if c.conf.OvpnTCPStatus != "" {
		_ = level.Debug(c.logger).Log("task", "Collecting TCP", "target", c.conf.OvpnTCPStatus)
		sess, product, version, err := getOpenVPNSessions("", c.conf.OvpnTCPStatus, "tcp", c.logger)
		if err != nil {
			_ = level.Error(c.logger).Log("task", "Collecting TCP", "status", "ERROR", "msg", err)
		} else {
			allSessions = append(allSessions, sess...)
			if product != "" && version != "" {
				products = append(products, product)
				versions = append(versions, version)
			}
		}
	}

	// Collect UDP sessions
	if c.conf.OvpnUDPStatus != "" {
		_ = level.Debug(c.logger).Log("task", "Collecting UDP", "target", c.conf.OvpnUDPStatus)
		sess, product, version, err := getOpenVPNSessions("", c.conf.OvpnUDPStatus, "udp", c.logger)
		if err != nil {
			_ = level.Error(c.logger).Log("task", "Collecting UDP", "status", "ERROR", "msg", err)
		} else {
			allSessions = append(allSessions, sess...)
			if product != "" && version != "" {
				products = append(products, product)
				versions = append(versions, version)
			}
		}
	}

	// If both failed, report failure
	if len(allSessions) == 0 {
		ch <- prometheus.MustNewConstMetric(ovpnProbeSuccess, prometheus.GaugeValue, 0, "")
		return
	}

	// Success probe - use first version found
	probeVersion := ""
	if len(versions) > 0 {
		probeVersion = versions[0]
	}
	ch <- prometheus.MustNewConstMetric(ovpnProbeSuccess, prometheus.GaugeValue, 1, probeVersion)

	// Total sessions (combined from both TCP and UDP)
	ch <- prometheus.MustNewConstMetric(ovpnSessTotal, prometheus.GaugeValue, float64(len(allSessions)))

	// Software info for each unique product/version combination
	seen := make(map[string]bool)
	for i := range products {
		key := products[i] + ":" + versions[i]
		if !seen[key] {
			ch <- prometheus.MustNewConstMetric(ovpnInfo, prometheus.CounterValue, float64(1), products[i], versions[i])
			seen[key] = true
		}
	}

	// Per-client metrics
	for _, v := range allSessions {
		clientLabel := v.RemoteID + "_" + v.Protocol
		if bi, err := strconv.ParseFloat(v.BytesIn, 64); err == nil {
			ch <- prometheus.MustNewConstMetric(ovpnBytesInTotal, prometheus.CounterValue, float64(bi), clientLabel)
		}
		if bo, err := strconv.ParseFloat(v.BytesOut, 64); err == nil {
			ch <- prometheus.MustNewConstMetric(ovpnBytesOutTotal, prometheus.CounterValue, float64(bo), clientLabel)
		}
	}

	_ = level.Debug(c.logger).Log("task", "Collection complete", "total_sessions", len(allSessions))
}