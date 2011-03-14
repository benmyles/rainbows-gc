#!/bin/sh
. ./test-lib.sh
case $model in
EventMachine) ;;
*)
	t_info "skipping $T since it's not compatible with $model"
	exit 0
	;;
esac
RUBYLIB=$($RUBY test_isolate_cramp.rb):$RUBYLIB
export RUBYLIB
require_check cramp Cramp::VERSION

t_plan 7 "streaming test for Cramp"

CONFIG_RU=cramp/streaming.ru

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles a b c curl_err expect

	# requiring Rubygems for this test only since Cramp depends on
	# pre versions of several gems
	# Like the rest of the EM/async stuff, it's not Rack::Lint compatible
	rainbows -E deployment -D $CONFIG_RU -c $unicorn_config
	rainbows_wait_start
}

# this will spew any unexpected input to stdout and be silent on success
check () {
	(
		i=0
		while read hello world
		do
			t1=$(date +%s)
			diff=$(($t1 - $t0))
			t_info "i=$i diff=$diff hello=$hello world=$world"
			test $diff -ge 1 || echo "$i: diff: $diff < 1 second"
			t0=$t1
			test xHello = x"$hello" || echo "$i: Hello != $hello"
			test xWorld = x"$world" || echo "$i: World != $world"
			i=$(($i + 1))
			test $i -le 3 || echo "$i: $i > 3"
		done
	)
}

t_begin "send async requests off in parallel" && {
	t0=$(date +%s)
	curl --no-buffer -sSf http://$listen/ 2>> $curl_err | check >$a 2>&1 &
	curl --no-buffer -sSf http://$listen/ 2>> $curl_err | check >$b 2>&1 &
	curl --no-buffer -sSf http://$listen/ 2>> $curl_err | check >$c 2>&1 &
}

t_begin "wait for curl terminations" && {
	wait
	t1=$(date +%s)
	elapsed=$(( $t1 - $t0 ))
	t_info "elapsed=$elapsed (should be 4-5s)"
}

t_begin "termination signal sent" && {
	kill $rainbows_pid
}

t_begin "no errors from curl" && {
	test ! -s $curl_err
}

t_begin "no errors in stderr" && check_stderr

t_begin "silence is golden" && {
	test ! -s $a
	test ! -s $b
	test ! -s $c
}

t_done
