#!/bin/sh
. ./test-lib.sh
case $model in
ThreadSpawn|ThreadPool) ;;
RevThreadSpawn|RevThreadPool) ;;
CoolioThreadSpawn|CoolioThreadPool) ;;
*) t_info "$0 is only compatible with Thread*"; exit 0 ;;
esac

t_plan 6 "ThreadTimeout Rack middleware test for $model"

t_begin "configure and start" && {
	rtmpfiles curl_err
	rainbows_setup
	rainbows -D t9100.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "normal request should not timeout" && {
	test x"HI" = x"$(curl -sSf http://$listen/ 2>> $curl_err)"
}

t_begin "sleepy request times out with 408" && {
	rm -f $ok
	curl -sSf http://$listen/2 2>> $curl_err || > $ok
	test -e $ok
	grep 408 $curl_err
}

t_begin "short requests do not timeout while making a long one" && {
	rm -f $ok $curl_err
	> $ok
	curl -sSf http://$listen/2 2>$curl_err >/dev/null &
	(
		for i in $(awk </dev/null 'BEGIN{for(i=20;--i>=0;)print i}')
		do
			curl -sSf http://$listen/0.1 >> $ok 2>&1 &
			test x"HI" = x"$(curl -sSf http://$listen/0.05)"
		done
		wait
	)
	test x"HI" = x"$(curl -sSf http://$listen/)"
	wait
	test -f $ok
	test 20 -eq $(grep '^HI$' $ok | wc -l)
	test x = x"$(grep -v '^HI$' $ok)"
	grep 408 $curl_err
}

t_begin "kill server" && {
	kill $rainbows_pid
}

t_begin "no errors in Rainbows! stderr" && {
	check_stderr
}

t_done
