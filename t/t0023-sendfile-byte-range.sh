#!/bin/sh
. ./test-lib.sh
test -r random_blob || die "random_blob required, run with 'make $0'"
case $RUBY_ENGINE in
ruby) ;;
*)
	t_info "skipping $T since it can't load the sendfile gem, yet"
	exit 0
	;;
esac

skip_models EventMachine NeverBlock

t_plan 13 "sendfile byte range response for $model"

t_begin "setup and startup" && {
	rtmpfiles out err
	rainbows_setup $model
	echo 'require "sendfile"' >> $unicorn_config
	echo 'def (::IO).copy_stream(*x); abort "NO"; end' >> $unicorn_config

	# can't load Rack::Lint here since it clobbers body#to_path
	rainbows -E none -D large-file-response.ru -c $unicorn_config
	rainbows_wait_start
}

. ./byte-range-common.sh
