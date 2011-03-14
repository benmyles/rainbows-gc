#!/bin/sh
. ./test-lib.sh

# n - number of seconds to sleep
n=10
CONFIG_RU=async_sinatra.ru
case $model in
NeverBlock|EventMachine) ;;
*)
	t_info "skipping $T since it's not compatible with $model"
	exit 0
	;;
esac

t_plan 7 "async_sinatra test for EM"

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles a b c curl_err

	# Async Sinatra does not support Rack::Lint
	rainbows -E none -D $CONFIG_RU -c $unicorn_config
	rainbows_wait_start
}

t_begin "send async requests off in parallel" && {
	t0=$(date +%s)
	( curl --no-buffer -sSf http://$listen/$n 2>> $curl_err | utee $a) &
	( curl --no-buffer -sSf http://$listen/$n 2>> $curl_err | utee $b) &
	( curl --no-buffer -sSf http://$listen/$n 2>> $curl_err | utee $c) &
}

t_begin "ensure elapsed requests were processed in parallel" && {
	wait
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	echo "elapsed=$elapsed < 30"
	test $elapsed -lt 30
}

t_begin "termination signal sent" && {
	kill $rainbows_pid
}

dbgcat a
dbgcat b
dbgcat c
dbgcat r_err
dbgcat curl_err

t_begin "no errors from curl" && {
	test ! -s $curl_err
}

t_begin "no errors in stderr" && check_stderr

dbgcat r_err

t_begin "no responses are chunked" && {
	test x"$(cat $a)" = x"delayed for $n seconds"
	test x"$(cat $b)" = x"delayed for $n seconds"
	test x"$(cat $c)" = x"delayed for $n seconds"
}

t_done
