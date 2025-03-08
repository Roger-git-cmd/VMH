#!/bin/bash
set -e

FORBIDDEN_UTILS="socat nc netcat php lua telnet ncat cryptcat rlwrap msfconsole hydra medusa john hashcat sqlmap metasploit empire cobaltstrike ettercap bettercap responder mitmproxy evil-winrm chisel ligolo revshells powershell certutil bitsadmin smbclient impacket-scripts smbmap crackmapexec enum4linux ldapsearch onesixtyone snmpwalk zphisher socialfish blackeye weeman aircrack-ng reaver pixiewps wifite kismet horst wash bully wpscan commix xerosploit slowloris hping iodine iodine-client iodine-server"

PORT=${PORT:-8080}  
HEALTH_PORT=8081  

start_health_stub() {
    python3 - <<EOF &
import http.server
import socketserver

PORT = $HEALTH_PORT

class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_error(404, "Not Found")

    def log_message(self, format, *args):
        return

with socketserver.TCPServer(("0.0.0.0", PORT), HealthHandler) as httpd:
    print(f"Health check running on http://0.0.0.0:{PORT}/health")
    httpd.serve_forever()
EOF
}

keep_alive_local() {
    sleep 30
    if [ -z "$RENDER_EXTERNAL_HOSTNAME" ]; then
        echo "Error: RENDER_EXTERNAL_HOSTNAME is not set!"
        exit 1
    fi
    while true; do
        echo "Checking health at: http://$RENDER_EXTERNAL_HOSTNAME:$HEALTH_PORT/health"
        curl -s "http://$RENDER_EXTERNAL_HOSTNAME:$HEALTH_PORT/health" -o /dev/null
        sleep 30
    done
}

monitor_forbidden() {
    while true; do
        for cmd in $FORBIDDEN_UTILS; do
            if command -v "$cmd" >/dev/null 2>&1; then
                apt-get purge -y "$cmd" 2>/dev/null || true
            fi
        done
        sleep 10
    done
}

start_health_stub &  
keep_alive_local &  
monitor_forbidden &  

exec python -m hikka --port "$PORT"
