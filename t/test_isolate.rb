require 'rubygems'
require 'isolate'
engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'

path = "tmp/isolate/#{engine}-#{RUBY_VERSION}"
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
  gem 'unicorn', '3.4.0'
  gem 'kcar', '0.2.0'
  gem 'raindrops', '0.4.1'

  if engine == "ruby"
    gem 'sendfile', '1.1.0' # next Rubinius should support this
    gem 'cool.io', '1.0.0'

    gem 'eventmachine', '0.12.10'
    gem 'sinatra', '1.2.0'
    gem 'async_sinatra', '0.5.0'

    gem 'neverblock', '0.1.6.2'
  end

  if defined?(::Fiber) && engine == "ruby"
    gem 'revactor', '0.1.5'
    gem 'rack-fiber_pool', '0.9.1'
  end

  gem 'sleepy_penguin', '2.0.0' if RUBY_PLATFORM =~ /linux/
end

$stdout.reopen(old_out)

# don't load the old Rev if it exists, Cool.io 1.0.0 is compatible with it,
# even for everything Revactor uses.
dirs = Dir["#{path}/gems/*-*/lib"]
dirs.delete_if { |x| x =~ %r{/rev-[\d\.]+/lib} }
puts dirs.map { |x| File.expand_path(x) }.join(':')
