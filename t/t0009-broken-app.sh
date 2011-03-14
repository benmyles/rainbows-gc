#!/bin/sh
. ./test-lib.sh

t_plan 9 "graceful handling of broken apps for $model"

t_begin "setup and start" && {
	rainbows_setup $model 1
	rainbows -E none -D t0009.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "normal response is alright" && {
	test xOK = x"$(curl -sSf http://$listen/)"
}

t_begin "app raised exception" && {
	curl -sSf http://$listen/raise 2> $tmp || :
	grep -F 500 $tmp
	> $tmp
}

t_begin "app exception logged and backtrace not swallowed" && {
	grep -F 'app error' $r_err
	grep -A1 -F 'app error' $r_err | tail -1 | grep t0009.ru:
	dbgcat r_err
	> $r_err
}

t_begin "trigger bad response" && {
	curl -sSf http://$listen/nil 2> $tmp || :
	grep -F 500 $tmp
	> $tmp
}

t_begin "app exception logged" && {
	grep -F 'app error' $r_err
	> $r_err
}

t_begin "normal responses alright afterwards" && {
	> $tmp
	curl -sSf http://$listen/ >> $tmp &
	curl -sSf http://$listen/ >> $tmp &
	curl -sSf http://$listen/ >> $tmp &
	curl -sSf http://$listen/ >> $tmp &
	wait
	test xOK = x$(sort < $tmp | uniq)
}

t_begin "teardown" && {
	kill $rainbows_pid
}

t_begin "check stderr" && check_stderr

t_done
