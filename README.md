# Brothers in ARMs'access point docker image


![GitHub release (latest by date)](https://img.shields.io/github/v/release/biarms/access-point?label=Latest%20Github%20release&logo=Github)
![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/biarms/access-point?include_prereleases&label=Highest%20GitHub%20release&logo=Github&sort=semver)

[![TravisCI build status image](https://img.shields.io/travis/biarms/access-point/master?label=Travis%20build&logo=Travis)](https://travis-ci.org/biarms/access-point)
[![CircleCI build status image](https://img.shields.io/circleci/build/gh/biarms/access-point/master?label=CircleCI%20build&logo=CircleCI)](https://circleci.com/gh/biarms/access-point)

[![Docker Pulls image](https://img.shields.io/docker/pulls/biarms/access-point?logo=Docker)](https://hub.docker.com/r/biarms/access-point)
[![Docker Stars image](https://img.shields.io/docker/stars/biarms/access-point?logo=Docker)](https://hub.docker.com/r/biarms/access-point)
[![Highest Docker release](https://img.shields.io/docker/v/biarms/access-point?label=docker%20release&logo=Docker&sort=semver)](https://hub.docker.com/r/biarms/access-point)

## Overview
This project build a docker container running the [hostapd daemon](https://en.wikipedia.org/wiki/Hostapd) and a [dhcpd daemon](https://en.wikipedia.org/wiki/DHCPD). It's goal is to configured the 'wlan0' 
network interface as an wifi access point, which is able to run on any amd64 and arm devices (from arm32v6 to arm64v8).

Current implementation hardcode the usage of the `10.57.0.0/255.255.255.0` sub-network:
- `10.57.0.1` will be the IP of the access point gateway
- Wifi clients will obtain DHCP addresses inside the `[10.57.0.10 - 10.57.0.220]` range.

This project was hugely inspired from https://gitlab.com/hartek/autowlan.

## Usage
You could start your own access point with customized settings thanks to this docker-compose file: 
```
version: '3.7'
services:
  biarms-access-point:
    container_name: biarms-access-point
    image: biarms/access-point
    cap_add: 
      - NET_ADMIN
    stop_grace_period: 2m
    network_mode: "host"
    volumes: 
      - ./your-customized-hostapd.conf-file:/etc/hostapd/hostapd.conf
``` 
See for instance the [arm-docker-stacks infra access-point](https://github.com/biarms/arm-docker-stacks/tree/master/infra/access-point) configuration.

### References:
1. https://gitlab.com/hartek/autowlan / https://fwhibbit.es/en/automatic-access-point-with-docker-and-raspberry-pi-zero-w
2. https://wiki.alpinelinux.org/wiki/Wireless_AP_with_udhcpd_and_NAT
3. https://elinux.org/RPI-Wireless-Hotspot

## How to build locally
1. Option 1: with CircleCI Local CLI:
   - Install [CircleCI Local CLI](https://circleci.com/docs/2.0/local-cli/)
   - Call `circleci local execute`
2. Option 2: with make:
   - Install [GNU make](https://www.gnu.org/software/make/manual/make.html). Version 3.81 (which came out-of-the-box on MacOS) should be OK.
   - Call `make build`
