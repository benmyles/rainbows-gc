#!/bin/sh
. ./test-lib.sh

t_plan 4 "graceful exit test for $model"

t_begin "setup and startup" && {
	rtmpfiles curl_out
	rainbows_setup $model
	rainbows -D sleep.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "send a request and SIGQUIT while request is processing" && {
	curl -sSfv -T- </dev/null http://$listen/5 > $curl_out 2> $fifo &
	awk -v rainbows_pid=$rainbows_pid '
{ print $0 }
/100 Continue/ {
	print "awk: sending SIGQUIT to", rainbows_pid
	system("kill -QUIT "rainbows_pid)
}' $fifo
	wait
}

dbgcat r_err

t_begin 'response returned "Hello"' && {
	test x$(cat $curl_out) = xHello
}

t_begin 'stderr has no errors' && check_stderr

t_done
