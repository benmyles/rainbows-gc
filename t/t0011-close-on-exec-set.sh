#!/bin/sh
nr=${nr-"5"}
. ./test-lib.sh

t_plan 7 "ensure close-on-exec flag is set for $model"

t_begin "setup and start" && {
	rainbows_setup $model 1 1
	nr=$nr rainbows -E none -D fork-sleep.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "send keepalive req expect it to timeout in ~1s" && {
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
	t_info "elapsed=$elapsed (expecting >=1s)"
	test $elapsed -ge 1
}

t_begin 'sleep process is still running' && {
	sleep_pid="$(tail -1 $tmp)"
	kill -0 $sleep_pid
}

t_begin 'keepalive not unreasonably long' && {
	test $elapsed -lt $nr
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	t_info "about to start waiting $nr seconds..."
	sleep $nr
	check_stderr
}

t_begin 'sleep process is NOT running' && {
	if kill -0 $sleep_pid
	then
		die "sleep process should've died"
	fi
}

t_done
