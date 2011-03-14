#!/bin/sh
CONFIG_RU=${CONFIG_RU-'async-response.ru'}
. ./test-lib.sh

skip_models Base WriterThreadPool WriterThreadSpawn

t_plan 6 "async HTTP/1.0 response for $model"

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles a b c a_err b_err c_err
	# can't load Rack::Lint here since it'll cause Rev to slurp
	rainbows -E none -D $CONFIG_RU -c $unicorn_config
	rainbows_wait_start
}

t_begin "send async requests off in parallel" && {
	t0=$(date +%s)
	curl="curl -0 --no-buffer -vsSf http://$listen/"
	( $curl 2>> $a_err | utee $a) &
	( $curl 2>> $b_err | utee $b) &
	( $curl 2>> $c_err | utee $c) &
	wait
	t1=$(date +%s)
}

t_begin "ensure elapsed requests were processed in parallel" && {
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
dbgcat a_err

t_begin "no errors from curl" && {
	if grep -i Transfer-Encoding $a_err $b_err $c_err
	then
		die "Unexpected Transfer-Encoding: header"
	fi
	for i in $a_err $b_err $c_err
	do
		grep 'Connection: close' $i
	done
}

dbgcat r_err
t_begin "no errors in stderr" && check_stderr

t_done
