#!/bin/sh
. ./test-lib.sh
req_curl_chunked_upload_err_check

t_plan 6 "rack.input client_max_body_size zero"

t_begin "setup and startup" && {
	rtmpfiles curl_out curl_err
	rainbows_setup $model
	ed -s $unicorn_config <<EOF
,s/client_max_body_size.*/client_max_body_size 0/
w
EOF
	rainbows -D sha1-random-size.ru -c $unicorn_config
	rainbows_wait_start
	empty_sha1=da39a3ee5e6b4b0d3255bfef95601890afd80709
}

t_begin "regular request" && {
	curl -vsSf -H Expect: http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test x"$(cat $curl_out)" = x$empty_sha1
}

t_begin "chunked request" && {
	curl -vsSf -T- < /dev/null -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test x"$(cat $curl_out)" = x$empty_sha1
}

t_begin "small input chunked" && {
	rm -f $ok
	echo | \
	  curl -vsSf -T- -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err || > $ok
	dbgcat curl_err
	dbgcat curl_out
	fgrep 413 $curl_err
	test -e $ok
}

t_begin "small input content-length" && {
	rm -f $ok
	echo > $tmp
	curl -vsSf -T $tmp -H Expect: \
	  http://$listen/ > $curl_out 2> $curl_err || > $ok
	fgrep 413 $curl_err
	dbgcat curl_err
	dbgcat curl_out
	test -e $ok
}

t_begin "shutdown" && {
	kill $rainbows_pid
}

t_done
