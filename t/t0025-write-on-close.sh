#!/bin/sh
. ./test-lib.sh
t_plan 4 "write-on-close tests for funky response-bodies"

t_begin "setup and start" && {
	rainbows_setup
	rainbows -D -c $unicorn_config write-on-close.ru
	rainbows_wait_start
}

t_begin "write-on-close response body succeeds" && {
	test xGoodbye = x"$(curl -sSf --http1.0 http://$listen/)"
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
