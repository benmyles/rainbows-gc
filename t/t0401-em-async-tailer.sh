#!/bin/sh
nr=${nr-5}
. ./test-lib.sh
case $model in
NeverBlock|EventMachine) ;;
*)
	t_info "skipping $T since it's not compatible with $model"
	exit 0
	;;
esac

t_plan 8 "async_tailer test for test for EM"

CONFIG_RU=async_examples/async_tailer.ru

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles a b c curl_err TAIL_LOG_FILE expect

	printf '<h1>Async Tailer</h1><pre>' >> $expect

	export TAIL_LOG_FILE

	# this does not does not support Rack::Lint
	rainbows -E deployment -D $CONFIG_RU -c $unicorn_config
	rainbows_wait_start
}

t_begin "send async requests off in parallel" && {
	t0=$(date +%s)
	curl --no-buffer -sSf http://$listen/ > $a 2>> $curl_err &
	curl_a=$!
	curl --no-buffer -sSf http://$listen/ > $b 2>> $curl_err &
	curl_b=$!
	curl --no-buffer -sSf http://$listen/ > $c 2>> $curl_err &
	curl_c=$!
}

t_begin "generate log output" && {
	for i in $(awk "BEGIN {for(i=0;i<$nr;i++) print i}" < /dev/null)
	do
		date >> $TAIL_LOG_FILE
		sleep 1
	done
	# sometimes tail(1) can be slow
	sleep 2
}

t_begin "kill curls and wait for termination" && {
	kill $curl_a $curl_b $curl_c
	wait
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	t_info "elapsed=$elapsed"
}

t_begin "termination signal sent" && {
	kill -QUIT $rainbows_pid
}

t_begin "no errors from curl" && {
	test ! -s $curl_err
}

t_begin "no errors in stderr" && check_stderr

t_begin "responses match expected" && {
	cat $TAIL_LOG_FILE >> $expect
	cmp $expect $a
	cmp $expect $b
	cmp $expect $c
}

t_done
