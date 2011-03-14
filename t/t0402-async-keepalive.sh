#!/bin/sh
DELAY=${DELAY-1}
. ./test-lib.sh
case $model in
Coolio|NeverBlock|EventMachine) ;;
*)
	t_info "skipping $T since it's not compatible with $model"
	exit 0
	;;
esac

t_plan 12 "async_chunk_app test for test for $model"

CONFIG_RU=async_chunk_app.ru

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles a b c curl_err expect

	# this does not does not support Rack::Lint
	rainbows -E none -D $CONFIG_RU -c $unicorn_config
	rainbows_wait_start

	echo 'Hello World /0' >> $expect
	echo 'Hello World /1' >> $expect
	echo 'Hello World /2' >> $expect
}

t_begin "async.callback supports pipelining" && {
	rm -f $tmp
	t0=$(date +%s)
	(
		cat $fifo > $tmp &
		printf 'GET /0 HTTP/1.1\r\nHost: example.com\r\n\r\n'
		printf 'GET /1 HTTP/1.1\r\nHost: example.com\r\n\r\n'
		printf 'GET /2 HTTP/1.0\r\nHost: example.com\r\n\r\n'
		wait
	) | socat - TCP:$listen > $fifo
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	t_info "elapsed=$elapsed $model.$0 ($t_current)"
	test 3 -eq "$(fgrep 'HTTP/1.1 200 OK' $tmp | wc -l)"
	test 3 -eq "$(grep '^Hello ' $tmp | wc -l)"
	test 3 -eq "$(grep 'World ' $tmp | wc -l)"
}

t_begin "async.callback supports delayed pipelining" && {
	rm -f $tmp
	t0=$(date +%s)
	(
		cat $fifo > $tmp &
		printf 'GET /0 HTTP/1.1\r\nHost: example.com\r\n\r\n'
		sleep 1
		printf 'GET /1 HTTP/1.1\r\nHost: example.com\r\n\r\n'
		sleep 1
		printf 'GET /2 HTTP/1.0\r\nHost: example.com\r\n\r\n'
		wait
	) | socat - TCP:$listen > $fifo
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	t_info "elapsed=$elapsed $model.$0 ($t_current)"
	test 3 -eq "$(fgrep 'HTTP/1.1 200 OK' $tmp | wc -l)"
	test 3 -eq "$(grep '^Hello ' $tmp | wc -l)"
	test 3 -eq "$(grep 'World ' $tmp | wc -l)"
}

t_begin "async.callback supports pipelining with delay $DELAY" && {
	rm -f $tmp
	t0=$(date +%s)
	(
		cat $fifo > $tmp &
		printf 'GET /0 HTTP/1.1\r\nX-Delay: %d\r\n' $DELAY
		printf 'Host: example.com\r\n\r\n'
		printf 'GET /1 HTTP/1.1\r\nX-Delay: %d\r\n' $DELAY
		printf 'Host: example.com\r\n\r\n'
		printf 'GET /2 HTTP/1.0\r\nX-Delay: %d\r\n' $DELAY
		printf 'Host: example.com\r\n\r\n'
		wait
	) | socat - TCP:$listen > $fifo
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	min=$(( $DELAY * 3 ))
	t_info "elapsed=$elapsed $model.$0 ($t_current) min=$min"
	test $elapsed -ge $min
	test 3 -eq "$(fgrep 'HTTP/1.1 200 OK' $tmp | wc -l)"
	test 3 -eq "$(grep '^Hello ' $tmp | wc -l)"
	test 3 -eq "$(grep 'World ' $tmp | wc -l)"
}

t_begin "async.callback supports keepalive" && {
	t0=$(date +%s)
	curl -v --no-buffer -sSf http://$listen/[0-2] > $tmp 2>> $curl_err
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	t_info "elapsed=$elapsed $model.$0 ($t_current)"
	cmp $expect $tmp
	test 2 -eq "$(fgrep 'Re-using existing connection!' $curl_err |wc -l)"
	rm -f $curl_err
}

t_begin "async.callback supports keepalive with delay $DELAY" && {
	t0=$(date +%s)
	curl -v --no-buffer -sSf -H "X-Delay: $DELAY" \
	  http://$listen/[0-2] > $tmp 2>> $curl_err
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	min=$(( $DELAY * 3 ))
	t_info "elapsed=$elapsed $model.$0 ($t_current) min=$min"
	test $elapsed -ge $min
	cmp $expect $tmp
	test 2 -eq "$(fgrep 'Re-using existing connection!' $curl_err |wc -l)"
	rm -f $curl_err
}

t_begin "send async requests off in parallel" && {
	t0=$(date +%s)
	curl --no-buffer -sSf http://$listen/[0-2] > $a 2>> $curl_err &
	curl --no-buffer -sSf http://$listen/[0-2] > $b 2>> $curl_err &
	curl --no-buffer -sSf http://$listen/[0-2] > $c 2>> $curl_err &
}

t_begin "wait for curl terminations" && {
	wait
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	t_info "elapsed=$elapsed"
}

t_begin "termination signal sent" && {
	kill $rainbows_pid
}

t_begin "no errors from curl" && {
	test ! -s $curl_err
}

t_begin "no errors in stderr" && check_stderr

t_begin "responses match expected" && {
	cmp $expect $a
	cmp $expect $b
	cmp $expect $c
}

t_done

