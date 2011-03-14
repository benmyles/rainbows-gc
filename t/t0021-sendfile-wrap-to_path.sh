#!/bin/sh
. ./test-lib.sh
test -r random_blob || die "random_blob required, run with 'make $0'"
case $RUBY_ENGINE in
ruby) ;;
*)
	t_info "skipping $T since it can't load the sendfile gem, yet"
	exit 0
	;;
esac

t_plan 16 "sendfile wrap body response for $model"

t_begin "setup and startup" && {
	rtmpfiles out err http_fifo sub_ok
	rainbows_setup $model
	echo 'require "sendfile"' >> $unicorn_config
	echo 'def (::IO).copy_stream(*x); abort "NO"; end' >> $unicorn_config

	# can't load Rack::Lint here since it clobbers body#to_path
	export fifo
	rainbows -E none -D file-wrap-to_path.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "read random blob sha1" && {
	random_blob_sha1=$(rsha1 < random_blob)
}

t_begin "start FIFO reader" && {
	cat $fifo > $out &
}

t_begin "single request matches" && {
	sha1=$(curl -sSfv 2> $err http://$listen/random_blob | rsha1)
	test -n "$sha1"
	test x"$sha1" = x"$random_blob_sha1"
}

t_begin "body.close called" && {
	wait # for cat $fifo
	grep CLOSING $out || die "body.close not logged"
}

t_begin "start FIFO reader for abortive HTTP/1.1 request" && {
	cat $fifo > $out &
}

t_begin "send abortive HTTP/1.1 request" && {
	rm -f $ok
	(
		printf 'GET /random_blob HTTP/1.1\r\nHost: example.com\r\n\r\n'
		dd bs=4096 count=1 < $http_fifo >/dev/null
		echo ok > $ok
	) | socat - TCP:$listen > $http_fifo || :
	test xok = x$(cat $ok)
}

t_begin "body.close called for aborted HTTP/1.1 request" && {
	wait # for cat $fifo
	grep CLOSING $out || die "body.close not logged"
}

t_begin "start FIFO reader for abortive HTTP/1.0 request" && {
	cat $fifo > $out &
}

t_begin "send abortive HTTP/1.0 request" && {
	rm -f $ok
	(
		printf 'GET /random_blob HTTP/1.0\r\n\r\n'
		dd bs=4096 count=1 < $http_fifo >/dev/null
		echo ok > $ok
	) | socat - TCP:$listen > $http_fifo || :
	test xok = x$(cat $ok)
}

t_begin "body.close called for aborted HTTP/1.0 request" && {
	wait # for cat $fifo
	grep CLOSING $out || die "body.close not logged"
}

t_begin "start FIFO reader for abortive HTTP/0.9 request" && {
	cat $fifo > $out &
}

t_begin "send abortive HTTP/0.9 request" && {
	rm -f $ok
	(
		printf 'GET /random_blob\r\n'
		dd bs=4096 count=1 < $http_fifo >/dev/null
		echo ok > $ok
	) | socat - TCP:$listen > $http_fifo || :
	test xok = x$(cat $ok)
}

t_begin "body.close called for aborted HTTP/0.9 request" && {
	wait # for cat $fifo
	grep CLOSING $out || die "body.close not logged"
}

t_begin "shutdown server" && {
	kill -QUIT $rainbows_pid
}

t_begin "check stderr" && check_stderr

t_done
