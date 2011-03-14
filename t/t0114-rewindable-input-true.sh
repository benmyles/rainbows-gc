#!/bin/sh
. ./test-lib.sh
skip_models EventMachine NeverBlock
skip_models Rev RevThreadSpawn RevThreadPool
skip_models Coolio CoolioThreadSpawn CoolioThreadPool
skip_models Epoll XEpoll

t_plan 4 "rewindable_input toggled to true"

t_begin "setup and start" && {
	rainbows_setup
	echo rewindable_input true >> $unicorn_config
	rainbows -D -c $unicorn_config t0114.ru
	rainbows_wait_start
}

t_begin "ensure worker is started" && {
	test xOK = x$(curl -T t0114.ru -sSf http://$listen/)
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
