#!/bin/sh
. ./test-lib.sh
t_plan 6 "config variables conflict with preload_app"

t_begin "setup and start" && {
	rainbows_setup
	rtmpfiles ru

	cat > $ru <<\EOF
use Rack::ContentLength
use Rack::ContentType, "text/plain"
config = ru = { "hello" => "world" }
run lambda { |env| [ 200, {}, [ ru.inspect << "\n" ] ] }
EOF
	echo 'preload_app true' >> $unicorn_config
	rainbows -D -c $unicorn_config $ru
	rainbows_wait_start
}

t_begin "hit with curl" && {
	out=$(curl -sSf http://$listen/)
	test x"$out" = x'{"hello"=>"world"}'
}

t_begin "modify rackup file" && {
	ed -s $ru <<EOF
,s/world/WORLD/
w
EOF
}

t_begin "reload signal succeeds" && {
	kill -HUP $rainbows_pid
	rainbows_wait_start
	wait_for_reload
	wait_for_reap
}

t_begin "hit with curl" && {
	out=$(curl -sSf http://$listen/)
	test x"$out" = x'{"hello"=>"WORLD"}'
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_done
