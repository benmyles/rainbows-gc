#!/bin/sh
. ./test-lib.sh
case $model in
EventMachine) ;;
*)
	t_info "skipping $T since it's not compatible with $model"
	exit 0
	;;
esac

require_check rack/fiber_pool Rack::FiberPool

t_plan 7 "basic test with rack-fiber_pool gem"

CONFIG_RU=rack-fiber_pool/app.ru

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles curl_err curl_out

	rainbows -D -c $unicorn_config $CONFIG_RU
	rainbows_wait_start
}

t_begin "send requests off in parallel" && {
	curl --no-buffer -sSf http://$listen/ >> $curl_out 2>> $curl_err &
	curl --no-buffer -sSf http://$listen/ >> $curl_out 2>> $curl_err &
	curl --no-buffer -sSf http://$listen/ >> $curl_out 2>> $curl_err &
}

t_begin "wait for curl terminations" && {
	wait
}

t_begin "termination signal sent" && {
	kill $rainbows_pid
}

t_begin "no errors from curl" && {
	test ! -s $curl_err
}

t_begin "no errors in stderr" && check_stderr

t_begin "ensure we hit 3 separate fibers" && {
	test x3 = x"$(sort < $curl_out | uniq | wc -l)"
}

t_done
