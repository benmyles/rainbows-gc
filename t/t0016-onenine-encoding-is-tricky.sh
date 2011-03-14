#!/bin/sh
. ./test-lib.sh
t_plan 4 "proper handling of onenine encoding for $model"

t_begin "setup and startup" && {
	rainbows_setup $model
	rainbows -E none -D ./t0016.rb -c $unicorn_config
	rainbows_wait_start
	expect_sha1=8ff79d8115f9fe38d18be858c66aa08a1cc27a66
}

t_begin "response matches expected" && {
	rm -f $ok
	(
		curl -sSf http://$listen/ && echo ok > $ok
	) | rsha1 > $tmp
	test x$expect_sha1 = x"$(cat $tmp)"
}

t_begin "shutdown server" && {
	kill -QUIT $rainbows_pid
}

dbgcat r_err

t_begin "check stderr" && check_stderr

t_done
