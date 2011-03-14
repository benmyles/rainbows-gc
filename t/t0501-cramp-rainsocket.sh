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

t_plan 4 "WebSocket monkey patch validity test for Cramp"

CONFIG_RU=cramp/rainsocket.ru

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles curl_err

	# Like the rest of the EM/async stuff, it's not Rack::Lint compatible
	rainbows -E deployment -D $CONFIG_RU -c $unicorn_config
	rainbows_wait_start
}

t_begin "wait for server to say hello to us" && {
	ok=$((curl --no-buffer -sS http://$listen/ || :) | \
	     (tr -d '\0\0377' || :) | \
	     awk '/Hello from the Server/ { print "ok"; exit 0 }')

	test x"$ok" = xok
}

t_begin "termination signal sent" && {
	kill $rainbows_pid
}

t_begin "no errors in stderr" && check_stderr

t_done
