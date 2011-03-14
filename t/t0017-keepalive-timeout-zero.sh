#!/bin/sh
. ./test-lib.sh
t_plan 6 "keepalive_timeout 0 tests for $model"

t_begin "setup and start" && {
	rainbows_setup $model 2 0
	grep 'keepalive_timeout 0' $unicorn_config
	rainbows -D env.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin 'check server responds with Connection: close' && {
	curl -sSfi http://$listen/ | grep 'Connection: close'
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
	t_info "elapsed=$elapsed (expecting <=3)"
	test $elapsed -le 3
}

t_begin "'Connection: close' header set" && {
	grep 'Connection: close' $tmp
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
