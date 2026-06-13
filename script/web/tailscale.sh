#!/bin/sh

TS_DAEMON="/opt/muos/bin/tailscaled"
TS_CLI="/opt/muos/bin/tailscale"
TS_STATEDIR="/opt/muos/config/tailscale"
TS_SOCKET="/var/run/tailscale/tailscaled.sock"
TS_RUNDIR="/var/run/tailscale"

TS_RUNNING() {
	pgrep -f "$TS_DAEMON" >/dev/null 2>&1
}

TS_EXEC() {
	"$TS_CLI" --socket="$TS_SOCKET" "$@"
}

TS_IP() {
	TS_EXEC ip --4 2>/dev/null | head -1 | tr -d '\n'
}

case "$1" in
	start)
		if ! TS_RUNNING; then
			mkdir -p "$TS_STATEDIR" "$TS_RUNDIR"
			# Remove stale socket from a previous crash
			rm -f "$TS_SOCKET"
			"$TS_DAEMON" \
				--statedir="$TS_STATEDIR" \
				--socket="$TS_SOCKET" &
			# Wait for the socket to appear (up to 5s)
			i=0
			while [ ! -S "$TS_SOCKET" ] && [ "$i" -lt 10 ]; do
				sleep 0.5
				i=$((i + 1))
			done
		fi
		;;

	stop)
		TS_EXEC down >/dev/null 2>&1
		pkill -TERM tailscaled >/dev/null 2>&1
		sleep 0.5
		pkill -KILL tailscaled >/dev/null 2>&1
		rm -f "$TS_SOCKET"
		;;

	up)
		if [ -n "$2" ]; then
			TS_EXEC up --login-server="$2" >/dev/null 2>&1
		else
			TS_EXEC up >/dev/null 2>&1
		fi
		;;

	down)
		TS_EXEC down >/dev/null 2>&1
		;;

	logout)
		TS_EXEC logout >/dev/null 2>&1
		;;

	status)
		if [ ! -S "$TS_SOCKET" ]; then
			printf "Daemon Stopped"
			exit 0
		fi
		IP=$(TS_IP)
		if [ -n "$IP" ]; then
			printf "Connected - %s" "$IP"
		else
			printf "Not Connected"
		fi
		;;

	authurl)
		# Print the auth URL required to log in.
		# tailscale up with --timeout prints the URL immediately when auth is needed.
		if [ -n "$2" ]; then
			TS_EXEC up --login-server="$2" --timeout=2s 2>&1 | grep -o 'https://[^ ]*' | head -1
		else
			TS_EXEC up --timeout=2s 2>&1 | grep -o 'https://[^ ]*' | head -1
		fi
		;;

	*)
		printf "Usage: %s {start|stop|up|down|logout|status|authurl} [server_url]\n" "$0" >&2
		exit 1
		;;
esac

exit 0
