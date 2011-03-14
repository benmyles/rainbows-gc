#!/bin/sh
. ./test-lib.sh
t_plan 6 "keepalive_requests limit tests for $model"

t_begin "setup and start" && {
	rainbows_setup $model 50 666
	rtmpfiles curl_out curl_err
	grep 'keepalive_timeout 666' $unicorn_config
	rainbows -E none -D env.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "curl requests hit default keepalive_requests limit" && {
	curl -sSfv http://$listen/[0-101] > $curl_out 2> $curl_err
	test 1 -eq $(grep 'Connection: close' $curl_err |wc -l)
	test 101 -eq $(grep 'Connection: keep-alive' $curl_err |wc -l)
}

t_begin "reload with smaller keepalive_requests limit" && {
	ed -s $unicorn_config <<EOF
,g/Rainbows!/
a
  keepalive_requests 5
.
w
EOF
	kill -HUP $rainbows_pid
	test x"$(cat $fifo)" = xSTART
}

t_begin "curl requests hit smaller keepalive_requests limit" && {
	rm -f $curl_out $curl_err
	curl -sSfv http://$listen/[1-13] > $curl_out 2> $curl_err
	test 2 -eq $(grep 'Connection: close' $curl_err |wc -l)
	test 11 -eq $(grep 'Connection: keep-alive' $curl_err |wc -l)
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
