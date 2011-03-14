#!/bin/sh
. ./test-lib.sh

t_plan 7 "Sendfile middleware test for $model"

t_begin "configure and start" && {
	rtmpfiles curl_err
	rainbows_setup

	# do not allow default middleware to be loaded since it may
	# kill body#to_path
	rainbows -E none -D t9001.ru -c $unicorn_config
	rainbows_wait_start
	random_blob_sha1=$(rsha1 < random_blob)
}

t_begin "hit with curl" && {
	sha1=$(curl -sSfv http://$listen/ 2> $curl_err | rsha1)
}

t_begin "kill server" && {
	kill $rainbows_pid
}

t_begin "SHA1 matches source" && {
	test x$random_blob_sha1 = x$sha1
}

t_begin "no errors in Rainbows! stderr" && {
	check_stderr
}

t_begin "X-Sendfile does not show up in headers" && {
	dbgcat curl_err
	if grep -i x-sendfile $curl_err
	then
		die "X-Sendfile did show up!"
	fi
}

t_begin "Content-Length is set correctly in headers" && {
	expect=$(wc -c < random_blob)
	grep "^< Content-Length: $expect" $curl_err
}

t_done
