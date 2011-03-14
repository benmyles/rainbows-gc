#!/bin/sh
. ./test-lib.sh
test -r random_blob || die "random_blob required, run with 'make $0'"

t_plan 4 "rack.input short read tests"

t_begin "setup and startup" && {
	rtmpfiles curl_out curl_err
	rainbows_setup $model
	rainbows -D sha1-random-size.ru -c $unicorn_config
	blob_sha1=$(rsha1 < random_blob)
	t_info "blob_sha1=$blob_sha1"
	rainbows_wait_start
}

t_begin "regular request" && {
	curl -sSf -T random_blob http://$listen/ > $curl_out 2> $curl_err
	test x$blob_sha1 = x$(cat $curl_out)
	test ! -s $curl_err
}

t_begin "chunked request" && {
	curl -sSf -T- < random_blob http://$listen/ > $curl_out 2> $curl_err
	test x$blob_sha1 = x$(cat $curl_out)
	test ! -s $curl_err
}

t_begin "shutdown" && {
	kill $rainbows_pid
}

t_done
