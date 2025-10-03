package main

import (
	"fmt"
	"os"
	"gopkg.in/yaml.v2"
)

type Config struct {
	OvpnTCPStatus string `yaml:"ovpntcpstatus"`
	OvpnUDPStatus string `yaml:"ovpnudpstatus"`
	Version       string
	BuildDate     string
}

// Load YAML configuration file
func loadConfig(filename string) (*Config, error) {
	var config Config
	
	yamlFile, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	
	err = yaml.Unmarshal(yamlFile, &config)
	if err != nil {
		return nil, err
	}

	// Validate that at least one status file is configured
	if config.OvpnTCPStatus == "" && config.OvpnUDPStatus == "" {
		return nil, fmt.Errorf("at least one OpenVPN status file must be configured (ovpntcpstatus or ovpnudpstatus)")
	}
	
	return &config, nil
}