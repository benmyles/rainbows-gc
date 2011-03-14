#!/bin/sh
CONFIG_RU=${CONFIG_RU-'async-response.ru'}
. ./test-lib.sh

skip_models Base WriterThreadPool WriterThreadSpawn

case $CONFIG_RU in
*no-autochunk.ru)
	t_plan 7 "async response w/o autochunk for $model"
	skip_autochunk=true
	;;
*)
	t_plan 6 "async response for $model"
	skip_autochunk=false
	;;
esac

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles a b c curl_err
	# can't load Rack::Lint here since it'll cause Rev to slurp
	rainbows -E none -D $CONFIG_RU -c $unicorn_config
	rainbows_wait_start
}

t_begin "send async requests off in parallel" && {
	t0=$(date +%s)
	( curl --no-buffer -sSf http://$listen/ 2>> $curl_err | utee $a) &
	( curl --no-buffer -sSf http://$listen/ 2>> $curl_err | utee $b) &
	( curl --no-buffer -sSf http://$listen/ 2>> $curl_err | utee $c) &
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
dbgcat r_err
dbgcat curl_err

t_begin "no errors from curl" && {
	test ! -s $curl_err
}

t_begin "no errors in stderr" && check_stderr

dbgcat r_err

if $skip_autochunk
then
	t_begin "no responses are chunked" && {
		test x"$(cat $a)" = x0123456789
		test x"$(cat $b)" = x0123456789
		test x"$(cat $c)" = x0123456789
	}
fi

t_done
