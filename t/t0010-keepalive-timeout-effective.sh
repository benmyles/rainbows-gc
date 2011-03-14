#!/bin/sh
. ./test-lib.sh
t_plan 6 "keepalive_timeout tests for $model"

t_begin "setup and start" && {
	rainbows_setup
	rainbows -D env.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin 'check server up' && {
	curl -sSf http://$listen/
}

t_begin "send keepalive response that does not expect close" && {
	req='GET / HTTP/1.1\r\nHost: example.com\r\n\r\n'
	t0=$(date +%s)
	(
		cat $fifo > $tmp &
		printf "$req"
		wait
		date +%s > $ok
	) | socat - TCP:$listen > $fifo
	now="$(cat $ok)"
	elapsed=$(( $now - $t0 ))
	t_info "elapsed=$elapsed (expecting >=5s)"
	test $elapsed -ge 5
}

t_begin 'keepalive not unreasonably long' && {
	test $elapsed -lt 15
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
