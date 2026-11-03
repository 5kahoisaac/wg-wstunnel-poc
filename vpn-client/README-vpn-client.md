# Home-side WireGuard client — any router or host

The home side is just **a standard WireGuard client**. It consumes `peer_home.conf`
(generated on the VPS) and reaches the office subnets through the VPS. You have two
common choices:

- **A router with a WireGuard VPN client** (UniFi UDR, MikroTik, OpenWRT, pfSense/OPNsense,
  etc.) → routes the office subnets for the **whole home LAN**. Best for "every device at
  home can reach the office."
- **A single host running WireGuard** (`wg-quick`, or the official app on
  macOS/Windows/Linux/iOS/Android) → **that one machine** reaches the office. Simplest for
  a laptop.

> All IPs below are EXAMPLE values. Replace them with your own.

## 1. Get peer_home.conf
On the VPS:
```
docker exec wg-hub cat /config/peer_home/peer_home.conf
```

## 2. Edit three lines (see peer_home.conf.example)
- `Address    = 10.13.13.2/24`      ← keep the netmask (some routers reject it without one)
- `Endpoint   = <VPS_PUBLIC_IP>:51820`
- `AllowedIPs = 10.13.13.0/24, <OFFICE_ROUTES>`   (overlay + your office subnets)

Leave the keys untouched.

## 3a. If the client is a ROUTER
- Import `peer_home.conf` as a WireGuard VPN Client, bring it up (should show
  *Established* / *Connected*).
- Add a **scoped** policy route so LAN devices use the tunnel **only for office subnets**,
  not everything:
  - Source: the device(s) that should reach the office
  - Destination: your office subnets as IP ranges — **not** `Any` / `0.0.0.0/0`. Example:
    ```
    10.50.0.0  -  10.50.255.255
    10.60.0.0  -  10.60.255.255
    ```
- Scoping keeps normal internet (and any other VPNs) on their usual path.

## 3b. If the client is a single HOST
`wg-quick` example (the `AllowedIPs` in the config already scopes what is routed):
```bash
sudo cp peer_home.conf /etc/wireguard/wg0.conf
sudo wg-quick up wg0
# bring it down with:  sudo wg-quick down wg0
```
Only traffic to the subnets listed in `AllowedIPs` goes through the tunnel; the rest uses
your normal connection. On macOS/Windows/mobile, import the same file into the official
WireGuard app.

## 4. DNS (optional — only for reaching systems by name)
Reaching systems by **IP** needs no DNS. For names, see the **DNS** section in the main
[`README.md`](../README.md#-dns-reaching-internal-systems-by-name) — it lists several
options (per-machine `/etc/hosts`, a local resolver like Pi-hole/dnsmasq, Tailscale
split-DNS, or just using IPs).

## 5. Test (ICMP is often blocked on internal hosts — use curl, not ping)
```bash
curl -s -o /dev/null -w "%{http_code}\n" http://10.50.10.10/
```

## If it won't connect
- `Address` is missing the netmask.
- `Endpoint` is not `<VPS_PUBLIC_IP>:51820`.
- 51820/udp is not open on the VPS (cloud firewall AND OS firewall).
- The VPS `office` peer is not handshaking yet: on the VPS run `docker exec wg-hub wg show`.
