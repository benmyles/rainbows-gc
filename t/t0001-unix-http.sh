#!/bin/sh
. ./test-lib.sh
t_plan 19 "simple HTTP connection keepalive/pipelining tests for $model"

t_begin "checking for config.ru for $model" && {
	tbase=simple-http_$model.ru
	test -f "$tbase"
}

t_begin "setup and start" && {
	rtmpfiles unix_socket
	rainbows_setup
	echo "listen '$unix_socket'" >> $unicorn_config
	rainbows -D $tbase -c $unicorn_config
	rainbows_wait_start
}

t_begin "pid file exists" && {
	test -f $pid
}

t_begin "single TCP request" && {
	curl -sSfv http://$listen/
}

t_begin "handles client EOF gracefully" && {
	printf 'GET / HTTP/1.1\r\nHost: example.com\r\n\r\n' | \
		socat - UNIX:$unix_socket > $tmp
	dbgcat tmp
	if grep 'HTTP.* 500' $tmp
	then
		die "500 error returned on client shutdown(SHUT_WR)"
	fi
	check_stderr
}

dbgcat r_err

t_begin "pipelining partial requests" && {
	req='GET / HTTP/1.1\r\nHost: example.com\r\n'
	(
		cat $fifo > $tmp &
		printf "$req"'\r\n'"$req"
		sleep 1
		printf 'Connection: close\r\n\r\n'
		wait
		echo ok > $ok
	) | socat - UNIX:$unix_socket > $fifo
}
dbgcat tmp

t_begin "two HTTP/1.1 responses" && {
	test 2 -eq $(grep '^HTTP/1.1' $tmp | wc -l)
}

t_begin "two HTTP/1.1 200 OK responses" && {
	test 2 -eq $(grep '^HTTP/1.1 200 OK' $tmp | wc -l)
}

t_begin 'one "Connection: keep-alive" response' && {
	test 1 -eq $(grep '^Connection: keep-alive' $tmp | wc -l)
}

t_begin 'one "Connection: close" response' && {
	test 1 -eq $(grep '^Connection: close' $tmp | wc -l)
}

t_begin 'check subshell success' && {
	test x"$(cat $ok)" = xok
}


t_begin "check stderr" && {
	check_stderr
}

t_begin "burst pipelining requests" && {
	req='GET / HTTP/1.1\r\nHost: example.com\r\n'
	(
		cat $fifo > $tmp &
		printf "$req"'\r\n'"$req"'Connection: close\r\n\r\n'
		wait
		echo ok > $ok
	) | socat - UNIX:$unix_socket > $fifo
}

dbgcat tmp
dbgcat r_err

t_begin "two HTTP/1.1 responses" && {
	test 2 -eq $(grep '^HTTP/1.1' $tmp | wc -l)
}

t_begin "two HTTP/1.1 200 OK responses" && {
	test 2 -eq $(grep '^HTTP/1.1 200 OK' $tmp | wc -l)
}

t_begin 'one "Connection: keep-alive" response' && {
	test 1 -eq $(grep '^Connection: keep-alive' $tmp | wc -l)
}

t_begin 'one "Connection: close" response' && {
	test 1 -eq $(grep '^Connection: close' $tmp | wc -l)
}

t_begin 'check subshell success' && {
	test x"$(cat $ok)" = xok
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_done
