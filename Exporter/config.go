package main

type Config struct {
	OvpnTCPStatus string `yaml:"ovpn_tcp_status"`
	OvpnUDPStatus string `yaml:"ovpn_udp_status"`
	ServerName    string `yaml:"server_name"`
}