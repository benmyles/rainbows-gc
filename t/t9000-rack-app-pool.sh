#!/bin/sh
. ./test-lib.sh
case $model in
*CoolioThread*|*RevThread*|Thread*|*Fiber*|Revactor|NeverBlock) ;;
*)
	t_info "skipping $T since it's not compatible with $model"
	exit 0
	;;
esac
nr_client=30 APP_POOL_SIZE=4

t_plan 6 "AppPool Rack middleware test for $model"

t_begin "configure and start" && {
	rtmpfiles curl_out curl_err
	rainbows_setup $model 50
	APP_POOL_SIZE=$APP_POOL_SIZE rainbows -D t9000.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "launch $nr_client requests" && {
	start=$(date +%s)
	seq="$(awk "BEGIN{for(i=0;i<$nr_client;++i) print i}" </dev/null)"
	for i in $seq
	do
		curl -sSf http://$listen/ >> $curl_out 2>> $curl_err &
	done
	wait
	t_info elapsed=$(( $(date +%s) - $start ))
}

t_begin "kill server" && {
	kill $rainbows_pid
}

t_begin "$APP_POOL_SIZE instances of app were used" && {
	test $APP_POOL_SIZE -eq $(sort < $curl_out | uniq | wc -l)
}

t_begin "no errors in curl stderr" && {
	test ! -s $curl_err
}

t_begin "no errors in Rainbows! stderr" && {
	check_stderr
}

t_done
