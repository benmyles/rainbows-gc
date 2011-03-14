#!/bin/sh
. ./test-lib.sh
case $model in
EventMachine) ;;
*)
	t_info "skipping $T since it's not compatible with $model"
	exit 0
	;;
esac

t_plan 5 "basic test for app.deferred? usage"

CONFIG_RU=app_deferred.ru

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles deferred_err deferred_out sync_err sync_out
	rainbows -D -c $unicorn_config $CONFIG_RU
	rainbows_wait_start
}

t_begin "synchronous requests run in the same thread" && {
	curl --no-buffer -sSf http://$listen/ >> $sync_out 2>> $sync_err &
	curl --no-buffer -sSf http://$listen/ >> $sync_out 2>> $sync_err &
	curl --no-buffer -sSf http://$listen/ >> $sync_out 2>> $sync_err &
	wait
	test ! -s $sync_err
	test 3 -eq "$(wc -l < $sync_out)"
	test 1 -eq "$(uniq < $sync_out | wc -l)"
}

t_begin "deferred requests run in a different thread" && {
	curl -sSf http://$listen/deferred >> $deferred_out 2>> $deferred_err
	test ! -s $deferred_err
	sync_thread="$(uniq < $sync_out)"
	test x"$(uniq < $deferred_out)" != x"$sync_thread"
}

t_begin "termination signal sent" && {
	kill $rainbows_pid
}

t_begin "no errors in stderr" && check_stderr

t_done
