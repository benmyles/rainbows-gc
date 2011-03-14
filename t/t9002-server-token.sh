#!/bin/sh
. ./test-lib.sh
case $model in
Base) ;;
*) exit 0 ;; # don't waste cycles on trivial stuff :P
esac

t_plan 6 "ServerToken Rack middleware test for $model"

t_begin "configure and start" && {
	rtmpfiles curl_out curl_err
	rainbows_setup
	rainbows -D t9002.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "hit with curl" && {
	curl -sSfiI http://$listen/ > $curl_out 2> $curl_err
}

t_begin "kill server" && {
	kill $rainbows_pid
}

t_begin "no errors in curl stderr" && {
	test ! -s $curl_err
}

t_begin "no errors in Rainbows! stderr" && {
	check_stderr
}

t_begin "Server: token added" && {
	grep Server: $curl_out
}

t_done
