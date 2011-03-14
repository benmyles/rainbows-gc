#!/bin/sh
. ./test-lib.sh
t_plan 7 "ensure worker follows master to death"

t_begin "setup" && {
	rtmpfiles curl_err curl_out
	rainbows_setup
	echo timeout 3 >> $unicorn_config
	rainbows -D -c $unicorn_config worker-follows-master-to-death.ru
	rainbows_wait_start
}

t_begin "read worker PID" && {
	worker_pid=$(curl -sSf http://$listen/pid)
	t_info "worker_pid=$worker_pid"
}

t_begin "start a long sleeping request" && {
	curl -sSfv -T- </dev/null http://$listen/sleep/2 >$curl_out 2> $fifo &
	curl_pid=$!
	t_info "curl_pid=$curl_pid"
}

t_begin "nuke the master once we're connected" && {
	awk -v rainbows_pid=$rainbows_pid '
{ print $0 }
/100 Continue/ {
	print "awk: sending SIGKILL to", rainbows_pid
	system("kill -9 "rainbows_pid)
}' < $fifo > $curl_err
	wait
}

t_begin "worker is no longer running" && {
	nr=30
	while kill -0 $worker_pid 2>/dev/null && test $nr -gt 0
	do
		nr=$(( $nr - 1))
		sleep 1
	done
	kill -0 $worker_pid 2> $tmp && false
	test -s $tmp
}

t_begin "sleepy curl request is no longer running" && {
	kill -0 $curl_pid 2> $tmp && false
	test -s $tmp
}

t_begin "sleepy curl request completed gracefully" && {
	test x$(cat $curl_out) = x$worker_pid
	dbgcat curl_err
}

t_done
