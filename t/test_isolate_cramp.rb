require 'rubygems'
require 'isolate'
engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'

path = "tmp/isolate/#{engine}-#{RUBY_VERSION}/cramp"
opts = {
  :system => false,
  # we want "ruby-1.8.7" and not "ruby-1.8", so disable multiruby
  :multiruby => false,
  :path => path,
}

old_out = $stdout.dup
$stdout.reopen($stderr)

lock = File.open(__FILE__, "rb")
lock.flock(File::LOCK_EX)
Isolate.now!(opts) do
  if engine == "ruby"
    gem 'cramp', '0.12'
  end
end

$stdout.reopen(old_out)
dirs = Dir["#{path}/gems/*-*/lib"]
puts dirs.map { |x| File.expand_path(x) }.join(':')
