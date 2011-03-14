#!/bin/sh
. ./test-lib.sh
t_plan 25 "simple HTTP connection keepalive/pipelining tests for $model"

t_begin "checking for config.ru for $model" && {
	tbase=simple-http_$model.ru
	test -f "$tbase"
}

t_begin "setup and start" && {
	rainbows_setup
	rainbows -D $tbase -c $unicorn_config
	rainbows_wait_start
}

t_begin "pid file exists" && {
	test -f $pid
}

t_begin "single request" && {
	curl -sSfv http://$listen/
}

t_begin "handles client EOF gracefully" && {
	printf 'GET / HTTP/1.1\r\nHost: example.com\r\n\r\n' | \
		socat - TCP4:$listen > $tmp
	dbgcat tmp
	if grep 'HTTP.* 500' $tmp
	then
		die "500 error returned on client shutdown(SHUT_WR)"
	fi
	check_stderr
}

dbgcat r_err

t_begin "two requests with keepalive" && {
	curl -sSfv http://$listen/a http://$listen/b > $tmp 2>&1
}

dbgcat r_err
dbgcat tmp

t_begin "reused existing connection" && {
	grep 'Re-using existing connection' < $tmp
}

t_begin "pipelining partial requests" && {
	req='GET / HTTP/1.1\r\nHost: example.com\r\n'
	(
		cat $fifo > $tmp &
		printf "$req"'\r\n'"$req"
		sleep 1
		printf 'Connection: close\r\n\r\n'
		wait
		echo ok > $ok
	) | socat - TCP:$listen > $fifo
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
	) | socat - TCP:$listen > $fifo
}

dbgcat tmp
dbgcat r_err

t_begin "got 2 HTTP/1.1 responses from pipelining" && {
	test 2 -eq $(grep '^HTTP/1.1' $tmp | wc -l)
}

t_begin "got 2 HTTP/1.1 200 OK responses" && {
	test 2 -eq $(grep '^HTTP/1.1 200 OK' $tmp | wc -l)
}

t_begin "one keepalive connection" && {
	test 1 -eq $(grep '^Connection: keep-alive' $tmp | wc -l)
}

t_begin "second request closes connection" && {
	test 1 -eq $(grep '^Connection: close' $tmp | wc -l)
}

t_begin "subshell exited correctly" && {
	test x"$(cat $ok)" = xok
}

t_begin "stderr log has no errors" && {
	check_stderr
}

t_begin "HTTP/0.9 request should not return headers" && {
	(
		printf 'GET /\r\n'
		cat $fifo > $tmp &
		wait
		echo ok > $ok
	) | socat - TCP:$listen > $fifo
}

dbgcat tmp
dbgcat r_err

t_begin "env.inspect should've put everything on one line" && {
	test 1 -eq $(wc -l < $tmp)
}

t_begin "no headers in output" && {
	if grep ^Connection: $tmp
	then
		die "Connection header found in $tmp"
	elif grep ^HTTP/ $tmp
	then
		die "HTTP/ found in $tmp"
	fi
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_done
