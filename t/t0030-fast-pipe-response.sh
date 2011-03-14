#!/bin/sh
. ./test-lib.sh
test -r random_blob || die "random_blob required, run with 'make $0'"

t_plan 10 "fast pipe response for $model"

t_begin "setup and startup" && {
	rtmpfiles err out
	rainbows_setup $model
	rainbows -E none -D fast-pipe-response.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "read random blob sha1" && {
	random_blob_sha1=$(rsha1 < random_blob)
	three_sha1=$(cat random_blob random_blob random_blob | rsha1)
}

t_begin "single request matches" && {
	sha1=$(curl -sSfv 2> $err http://$listen/ | rsha1)
	test -n "$sha1"
	test x"$sha1" = x"$random_blob_sha1"
}

t_begin "Content-Length header preserved in response" && {
	grep "^< Content-Length:" $err
}

t_begin "send three keep-alive requests" && {
	sha1=$(curl -vsSf 2> $err \
	       http://$listen/ http://$listen/ http://$listen/ | rsha1)
	test -n "$sha1"
	test x"$sha1" = x"$three_sha1"
}

t_begin "ensure responses were all keep-alive" && {
	test 3 -eq $(grep '< Connection: keep-alive' < $err | wc -l)
}

t_begin "HTTP/1.0 test" && {
	sha1=$(curl -0 -v 2> $err -sSf http://$listen/ | rsha1)
	test $sha1 = $random_blob_sha1
	grep '< Connection: close' < $err
}

t_begin "HTTP/0.9 test" && {
	(
		printf 'GET /\r\n'
		rsha1 < $fifo > $tmp &
		wait
		echo ok > $ok
	) | socat - TCP:$listen > $fifo
	test $(cat $tmp) = $random_blob_sha1
	test xok = x$(cat $ok)
}

t_begin "shutdown server" && {
	kill -QUIT $rainbows_pid
}

t_begin "check stderr" && check_stderr

t_done
