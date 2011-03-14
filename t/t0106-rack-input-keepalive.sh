#!/bin/sh
. ./test-lib.sh
t_plan 11 "rack.input pipelining test"

t_begin "setup and startup" && {
	rainbows_setup $model
	rtmpfiles req
	rainbows -D sha1.ru -c $unicorn_config
	body=hello
	body_size=$(printf $body | wc -c)
	body_sha1=$(printf $body | rsha1)
	random_blob_size=$(wc -c < random_blob)
	random_blob_sha1=$(rsha1 < random_blob)
	rainbows_wait_start
}

t_begin "send big pipelined chunked requests" && {
	(
		cat $fifo > $tmp &
		Connection=keep-alive
		export Connection
		content-md5-put < random_blob
		content-md5-put < random_blob
		content-md5-put < random_blob
		printf 'PUT / HTTP/1.0\r\n'
		printf 'Content-Length: %d\r\n\r\n' $random_blob_size
		cat random_blob
		wait
		echo ok > $ok
	) | socat - TCP4:$listen > $fifo
	test x"$(cat $ok)" = xok
}

t_begin "check responses" && {
	dbgcat tmp
	test 4 -eq $(grep $random_blob_sha1 $tmp | wc -l)
}

t_begin "send big pipelined identity requests" && {
	(
		cat $fifo > $tmp &
		printf 'PUT / HTTP/1.0\r\n'
		printf 'Connection: keep-alive\r\n'
		printf 'Content-Length: %d\r\n\r\n' $random_blob_size
		cat random_blob
		printf 'PUT / HTTP/1.1\r\n'
		printf 'Content-Length: %d\r\n\r\n' $random_blob_size
		cat random_blob
		printf 'PUT / HTTP/1.0\r\n'
		printf 'Content-Length: %d\r\n\r\n' $random_blob_size
		cat random_blob
		wait
		echo ok > $ok
	) | socat - TCP4:$listen > $fifo
	test x"$(cat $ok)" = xok
}

t_begin "check responses" && {
	dbgcat tmp
	test 3 -eq $(grep $random_blob_sha1 $tmp | wc -l)
}

t_begin "send pipelined identity requests" && {

	{
		printf 'PUT / HTTP/1.0\r\n'
		printf 'Connection: keep-alive\r\n'
		printf 'Content-Length: %d\r\n\r\n%s' $body_size $body
		printf 'PUT / HTTP/1.1\r\nHost: example.com\r\n'
		printf 'Content-Length: %d\r\n\r\n%s' $body_size $body
		printf 'PUT / HTTP/1.0\r\n'
		printf 'Content-Length: %d\r\n\r\n%s' $body_size $body
	} > $req
	(
		cat $fifo > $tmp &
		cat $req
		wait
		echo ok > $ok
	) | socat - TCP4:$listen > $fifo
	test x"$(cat $ok)" = xok
}

t_begin "check responses" && {
	dbgcat tmp
	test 3 -eq $(grep $body_sha1 $tmp | wc -l)
}

t_begin "send pipelined chunked requests" && {

	{
		printf 'PUT / HTTP/1.0\r\n'
		printf 'Connection: keep-alive\r\n'
		printf 'Transfer-Encoding: chunked\r\n\r\n'
		printf '%x\r\n%s\r\n0\r\n\r\n' $body_size $body
		printf 'PUT / HTTP/1.1\r\nHost: example.com\r\n'
		printf 'Transfer-Encoding: chunked\r\n\r\n'
		printf '%x\r\n%s\r\n0\r\n\r\n' $body_size $body
		printf 'PUT / HTTP/1.0\r\n'
		printf 'Transfer-Encoding: chunked\r\n\r\n'
		printf '%x\r\n%s\r\n0\r\n\r\n' $body_size $body
	} > $req
	(
		cat $fifo > $tmp &
		cat $req
		wait
		echo ok > $ok
	) | socat - TCP4:$listen > $fifo
	test x"$(cat $ok)" = xok
}

t_begin "check responses" && {
	dbgcat tmp
	test 3 -eq $(grep $body_sha1 $tmp | wc -l)
}

t_begin "kill server" && kill $rainbows_pid

t_begin "no errors in stderr log" && check_stderr

t_done
