#!/bin/sh
. ./test-lib.sh

t_plan 4 'ensure ENV["RACK_ENV"] is set correctly for '$model

finish_checks () {
	kill $rainbows_pid
	test ! -s $curl_err
	check_stderr
}

t_begin "setup" && {
	rtmpfiles curl_out curl_err
}

t_begin "default RACK_ENV is 'development'" && {
	rainbows_setup
	rainbows -D -c $unicorn_config env_rack_env.ru
	rainbows_wait_start
	test x"$(curl -sSf http://$listen 2>$curl_err)" = x"development"
	finish_checks
}

t_begin "RACK_ENV from process ENV is inherited" && {
	rainbows_setup
	( RACK_ENV=production rainbows -D -c $unicorn_config env_rack_env.ru )
	rainbows_wait_start
	test x$(curl -sSf http://$listen 2>$curl_err) = x"production"
	finish_checks
}

t_begin "RACK_ENV from -E is set" && {
	rainbows_setup
	rainbows -D -c $unicorn_config -E none env_rack_env.ru
	rainbows_wait_start
	test x$(curl -sSf http://$listen 2>$curl_err) = x"none"
	finish_checks
}

t_done
