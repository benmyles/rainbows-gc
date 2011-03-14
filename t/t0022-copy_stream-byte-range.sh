#!/bin/sh
. ./test-lib.sh
test -r random_blob || die "random_blob required, run with 'make $0'"
case $RUBY_VERSION in
1.9.*) ;;
*)
	t_info "skipping $T since it can't IO.copy_stream"
	exit 0
	;;
esac

case $model in
ThreadSpawn|WriterThreadSpawn|ThreadPool|WriterThreadPool|Base) ;;
*)
	t_info "skipping $T since it doesn't use IO.copy_stream"
	exit 0
	;;
esac

t_plan 13 "IO.copy_stream byte range response for $model"

t_begin "setup and startup" && {
	rtmpfiles out err
	rainbows_setup $model
	# can't load Rack::Lint here since it clobbers body#to_path
	rainbows -E none -D large-file-response.ru -c $unicorn_config
	rainbows_wait_start
}

. ./byte-range-common.sh
