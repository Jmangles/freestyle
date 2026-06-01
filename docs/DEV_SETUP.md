# Dev Setup Notes

## Testing Flutter Web on a Physical Device

Run the dev server bound to all network interfaces so a phone on the same WiFi can reach it:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Then open `http://<your-pc-local-ip>:8080` in the browser on your phone.
Find your PC's local IP with `ipconfig` — look for the IPv4 address under the WiFi adapter.

### Windows Firewall

Windows blocks inbound connections by default, so you need to temporarily open the port:

```powershell
# Allow inbound connections on port 8080
New-NetFirewallRule -DisplayName "Flutter Web Dev" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow

# Remove the rule when done
Remove-NetFirewallRule -DisplayName "Flutter Web Dev"
```
