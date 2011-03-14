#!/bin/sh
if test -z "$V" || test 0 -eq "$V"
then
	exit 0
fi
. ./test-lib.sh
skip_models WriterThreadSpawn WriterThreadPool Base
t_plan 6 "keepalive_timeout CPU usage tests for $model"

t_begin "setup and start" && {
	rainbows_setup $model 50 666
	grep 'worker_connections 50' $unicorn_config
	grep 'keepalive_timeout 666' $unicorn_config
	rainbows -E deployment -D times.ru -c $unicorn_config
	rainbows_wait_start
}

t_begin 'read current times' && {
	eval "$(curl -sSf http://$listen/)"
	before_utime=$utime
	before_stime=$stime
	echo "utime=$utime stime=$stime"
}

t_begin 'keepalive connections' && {
	listen=$listen $RUBY -rsocket -e '
host, port = ENV["listen"].split(/:/)
port = port.to_i
socks = (1..49).map do |i|
  s = TCPSocket.new(host, port)
  # need to write something to get around deferred accepts
  s.write "GET /#{i} HTTP/1.1\r\nHost: example.com\r\n\r\n"
  s.readpartial 16384
  s
end
sleep
	' &
	ruby_pid=$!
	for i in $(awk 'BEGIN { for(i=0;i<60;++i) print i }' </dev/null)
	do
		sleep 1
		eval "$(curl -sSf http://$listen/)"
		echo "utime[$i] $before_utime => $utime" \
		     "stime[$i] $before_stime => $stime"
	done
	kill $ruby_pid
}

t_begin "times not unreasonable" && {
	echo "utime: $before_utime => $utime" \
	     "stime: $before_stime => $stime"
}

t_begin "killing succeeds" && {
	kill $rainbows_pid
}

t_begin "check stderr" && {
	check_stderr
}

t_done
