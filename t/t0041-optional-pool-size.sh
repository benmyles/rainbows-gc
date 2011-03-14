#!/bin/sh
. ./test-lib.sh

case $model in
NeverBlock|CoolioThreadPool) ;;
*)
	t_info "skipping $T since it doesn't support :pool_size"
	exit
	;;
esac

t_plan 6 "optional :pool_size argument for $model"

t_begin "setup and startup" && {
	rtmpfiles curl_out curl_err
	rainbows_setup $model
}

t_begin "fails with bad :pool_size" && {
	ed -s $unicorn_config <<EOF
,s/use :$model/use :$model, :pool_size => -666/
w
EOF
	grep "pool_size" $unicorn_config
	rainbows -D env.ru -c $unicorn_config || echo err=$? > $ok
	test x"$(cat $ok)" = "xerr=1"
}

t_begin "starts with correct :pool_size" && {
	ed -s $unicorn_config <<EOF
,s/use :$model.*/use :$model, :pool_size => 6/
w
EOF
	grep "pool_size" $unicorn_config
	rainbows -D env.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin "regular TCP request works right" && {
	curl -sSfv http://$listen/
}

t_begin "no errors in stderr" && {
	check_stderr
}

t_begin "shutdown" && {
	kill $rainbows_pid
}

t_done
