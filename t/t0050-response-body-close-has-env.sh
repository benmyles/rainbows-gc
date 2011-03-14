#!/bin/sh
. ./test-lib.sh

t_plan 29 "keepalive does not clear Rack env prematurely for $model"

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles curl_out curl_err
	echo "preload_app true" >> $unicorn_config
	rainbows -D close-has-env.ru -c $unicorn_config
	rainbows_wait_start
}

req_pipelined () {
	pfx=$1
	t_begin "make pipelined requests to trigger $pfx response body" && {
		> $r_out
		(
			cat $fifo > $tmp &
			printf 'GET /%s/1 HTTP/1.1\r\n' $pfx
			printf 'Host: example.com\r\n\r\n'
			printf 'GET /%s/2 HTTP/1.1\r\n' $pfx
			printf 'Host: example.com\r\n\r\n'
			printf 'GET /%s/3 HTTP/1.1\r\n' $pfx
			printf 'Host: example.com\r\n'
			printf 'Connection: close\r\n\r\n'
			wait
			echo ok > $ok
		) | socat - TCP4:$listen > $fifo
		test xok = x$(cat $ok)
	}
}

reload () {
	t_begin 'reloading Rainbows! to ensure writeout' && {
		# ensure worker is loaded before HUP
		curl -s http://$listen/ >/dev/null
		# reload to ensure everything is flushed
		kill -HUP $rainbows_pid
		test xSTART = x"$(cat $fifo)"
	}
}

check_log () {
	pfx="$1"
	t_begin "check body close messages" && {
		< $r_out awk '
/^path_info=\/'$pfx'\/[1-3]$/ { next }
{ exit(2) }
END { exit(NR == 3 ? 0 : 1) }
'
	}
}

req_keepalive () {
	pfx="$1"
	t_begin "make keepalive requests to trigger $pfx response body" && {
		> $r_out
		rm -f $curl_err $curl_out
		curl -vsSf http://$listen/$pfx/[1-3] 2> $curl_err > $curl_out
	}
}

req_keepalive file
reload
check_log file

req_pipelined file
reload
check_log file

req_keepalive blob
reload
check_log blob

req_pipelined blob
reload
check_log blob

req_keepalive pipe
reload
check_log pipe

req_pipelined pipe
reload
check_log pipe

t_begin "enable sendfile gem" && {
	echo "require 'sendfile'" >> $unicorn_config
}

reload

req_keepalive file
reload
check_log file

req_pipelined file
reload
check_log file

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
