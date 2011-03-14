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

t_plan 7 "async_app test for test for EM"

CONFIG_RU=async_examples/async_app.ru

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles a b c curl_err expect

	# this does not does not support Rack::Lint
	rainbows -E deployment -D $CONFIG_RU -c $unicorn_config
	rainbows_wait_start
}

t_begin "send async requests off in parallel" && {
	t0=$(date +%s)
	curl --no-buffer -sSf http://$listen/ > $a 2>> $curl_err &
	curl --no-buffer -sSf http://$listen/ > $b 2>> $curl_err &
	curl --no-buffer -sSf http://$listen/ > $c 2>> $curl_err &
}

t_begin "wait for curl terminations" && {
	wait
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	t_info "elapsed=$elapsed"
}

t_begin "termination signal sent" && {
	kill $rainbows_pid
}

t_begin "no errors from curl" && {
	test ! -s $curl_err
}

t_begin "no errors in stderr" && check_stderr

t_begin "responses match expected" && {
	echo 'Woah, async!' > $expect
	printf 'Cheers then!' >> $expect
	cmp $expect $a
	cmp $expect $b
	cmp $expect $c
}

t_done
