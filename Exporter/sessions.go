package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"regexp"
	"strings"

	"github.com/go-kit/kit/log"
	"github.com/go-kit/log/level"
)

type SessionExport struct {
	Server      string `json:"server"`
	Protocol    string `json:"protocol"`
	P1Uniqueid  string `json:"p1uniqueid"`
	P2Uniqueid  string `json:"p2uniqueid"`
	State       string `json:"state"`
	RemoteHost  string `json:"remotehost"`
	RemotePort  string `json:"remoteport"`
	RemoteID    string `json:"remoteid"`
	RemoteTs    string `json:"remotets"`
	Established string `json:"established"`
	BytesIn     string `json:"bytesin"`
	BytesOut    string `json:"bytesout"`
	PacketsIn   string `json:"packetsin"`
	PacketsOut  string `json:"packetsout"`
}

// Get local OpenVPN connections
func sessionsHandler(w http.ResponseWriter, r *http.Request, conf *Config, logger log.Logger) {
	serverName := conf.ServerName
	if serverName == "" {
		serverName = "openvpn-server"
	}

	connExport, err := getAllOpenVPNSessions(serverName, conf, logger)
	if err != nil {
		w.WriteHeader(500)
		fmt.Fprint(w, err.Error())
		return
	}

	jsondata, err := json.Marshal(connExport)
	if err != nil {
		w.WriteHeader(500)
		fmt.Fprint(w, err.Error())
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	_, err = w.Write(jsondata)
	if err != nil {
		level.Error(logger).Log("task", "HTTP", "write", err.Error())
	}
}

// Get all OpenVPN sessions from both TCP and UDP status files
func getAllOpenVPNSessions(server string, conf *Config, logger log.Logger) ([]SessionExport, error) {
	var allSessions []SessionExport

	// Try to get TCP sessions
	if conf.OvpnTCPStatus != "" {
		sessions, _, _, err := getOpenVPNSessions(server, conf.OvpnTCPStatus, "tcp", logger)
		if err != nil {
			level.Warn(logger).Log("task", "read TCP status", "err", err.Error())
		} else {
			allSessions = append(allSessions, sessions...)
			level.Debug(logger).Log("task", "TCP sessions", "count", len(sessions))
		}
	}

	// Try to get UDP sessions
	if conf.OvpnUDPStatus != "" {
		sessions, _, _, err := getOpenVPNSessions(server, conf.OvpnUDPStatus, "udp", logger)
		if err != nil {
			level.Warn(logger).Log("task", "read UDP status", "err", err.Error())
		} else {
			allSessions = append(allSessions, sessions...)
			level.Debug(logger).Log("task", "UDP sessions", "count", len(sessions))
		}
	}

	if len(allSessions) == 0 {
		return nil, fmt.Errorf("no OpenVPN sessions found in any status file")
	}

	return allSessions, nil
}

// Get OpenVPN local sessions from a specific status file
func getOpenVPNSessions(server string, statusFile string, protocol string, logger log.Logger) (connExport []SessionExport, product string, version string, err error) {
	reVersion := regexp.MustCompile(`(?m)^TITLE\s+(?P<product>\S+)\s+(?P<version>\S+)\s`)
	reClient := regexp.MustCompile(`(?m)^CLIENT_LIST\s+(?P<CN>\S+?)\t(?P<RealIP>\S+?)\t(?P<vIPv4>\S+?)\t(?P<vIPv6>\S*?)\t(?P<rB>\S+?)\t(?P<sB>\S+?)\t(?P<startTime>.+?)\t(?P<unixTime>\S+?)\t(?P<Username>.+?)\t(?P<ClientID>\S+?)\t(?P<peerID>\S+?)\t(?P<dataCiphers>\S+?)`)
	var cexp SessionExport

	if statusFile == "" {
		return nil, "", "", fmt.Errorf("status file path is empty")
	}
	
	// Check if file exists
	if _, err := os.Stat(statusFile); os.IsNotExist(err) {
		return nil, "", "", fmt.Errorf("status file does not exist: %s", statusFile)
	}

	ovpnstats, err := os.ReadFile(statusFile)
	if err != nil {
		level.Error(logger).Log("task", "open status file", "file", statusFile, "err", err.Error())
		return nil, "", "", err
	}

	ver := reVersion.FindAllSubmatch(ovpnstats, -1)
	if ver != nil && len(ver[0]) == 3 {
		product = string(ver[0][1])
		version = string(ver[0][2])
	}

	match := reClient.FindAllSubmatch(ovpnstats, -1)
	for _, m1 := range match {
		clientList := make(map[string]string)
		for i, name := range reClient.SubexpNames() {
			if i != 0 && name != "" {
				clientList[name] = string(m1[i])
			}
		}
		
		cip := strings.Split(clientList["RealIP"], ":")
		cexp.RemoteHost = cip[0]
		if len(cip) > 1 {
			cexp.RemotePort = cip[1]
		}
		cexp.Server = server
		cexp.Protocol = protocol
		cexp.P1Uniqueid = clientList["peerID"]
		cexp.P2Uniqueid = clientList["ClientID"]
		cexp.RemoteID = clientList["CN"]
		cexp.State = "ESTABLISHED"
		cexp.RemoteTs = clientList["vIPv4"]
		cexp.BytesIn = clientList["rB"]
		cexp.BytesOut = clientList["sB"]
		cexp.Established = clientList["startTime"]
		cexp.PacketsIn = "0"
		cexp.PacketsOut = "0"

		connExport = append(connExport, cexp)
	}
	
	return connExport, product, version, nil
}