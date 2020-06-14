# 1. Define args usable during the pre-build phase
# BUILD_ARCH: the docker architecture, with a tailing '/'. For instance, "arm64v8/"
ARG BUILD_ARCH

FROM ${BUILD_ARCH}alpine:3.12

# Install packages - see https://wiki.alpinelinux.org/wiki/Wireless_AP_with_udhcpd_and_NAT / https://elinux.org/RPI-Wireless-Hotspot
RUN apk update && apk add iw hostapd dhcp iptables

# Configure network interfaces
ADD etc/network/interfaces /etc/network/interfaces

# Add Hostapd config (open by default)
ADD etc/hostapd/hostapd-open.conf /etc/hostapd/hostapd.conf

# Configure DHCPD
ADD etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf
# According to dhcpd man pages (http://manpages.ubuntu.com/manpages/xenial/man5/dhcpd.leases.5.html)
#    When  dhcpd is first installed, there is no lease database.   However, dhcpd requires that
#    a lease database be present before it will start.  To make  the  initial  lease  database,
#    just create an empty file called /var/lib/dhcp/dhcpd.leases.
RUN touch /var/lib/dhcp/dhcpd.leases

# Copy and execute init file
# Inspired from https://gitlab.com/hartek/autowlan
ADD scripts /scripts

ENTRYPOINT ["/bin/sh", "/scripts/entry-point.sh"]

ARG BUILD_DATE
ARG VCS_REF
LABEL \
	org.label-schema.build-date=$BUILD_DATE \
	org.label-schema.vcs-ref=$VCS_REF \
	org.label-schema.vcs-url="https://github.com/biarms/access-point"
