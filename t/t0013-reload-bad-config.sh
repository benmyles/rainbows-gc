#!/bin/sh
. ./test-lib.sh
t_plan 7 "reload config.ru error with preload_app true"

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles ru

	cat > $ru <<\EOF
use Rack::ContentLength
use Rack::ContentType, "text/plain"
x = { "hello" => "world" }
run lambda { |env| [ 200, {}, [ x.inspect << "\n" ] ] }
EOF
	echo 'preload_app true' >> $unicorn_config
	rainbows -D -c $unicorn_config $ru
	rainbows_wait_start
}

t_begin "hit with curl" && {
	out=$(curl -sSf http://$listen/)
	test x"$out" = x'{"hello"=>"world"}'
}

t_begin "introduce syntax error in rackup file" && {
	echo '...' >> $ru
}

t_begin "reload signal succeeds" && {
	kill -HUP $rainbows_pid
	rainbows_wait_start
	wait_for_reload $r_err error
	wait_for_reap
	> $r_err
}

t_begin "hit with curl" && {
	out=$(curl -sSf http://$listen/)
	test x"$out" = x'{"hello"=>"world"}'
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
