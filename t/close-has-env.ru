#\ -E none
use Rainbows::DevFdResponse
class ClosablePipe < ::IO
  attr_accessor :env

  def self.new(env)
    rv = popen "echo hello", "rb"
    rv.env = env
    rv
  end

  def close
    super
    $stdout.syswrite "path_info=#{@env['PATH_INFO']}\n"
  end
end

class ClosableFile < ::File
  attr_accessor :env
  alias to_path path
  def close
    super
    $stdout.syswrite "path_info=#{@env['PATH_INFO']}\n"
  end
end

class Blob
  def initialize(env)
    @env = env
  end

  def each(&block)
    yield "BLOB\n"
  end

  def close
    $stdout.syswrite "path_info=#{@env['PATH_INFO']}\n"
  end
end

run(lambda { |env|
  case env["PATH_INFO"]
  when %r{\A/pipe/}
    [ 200,
      [ %w(Content-Length 6), %w(Content-Type text/plain)],
      ClosablePipe.new(env)
    ]
  when %r{\A/file/}
    f = ClosableFile.open("env.ru", "rb")
    f.env = env
    [ 200, {
      'X-Req-Path' => env["PATH_INFO"],
      'Content-Length' => f.stat.size.to_s,
      'Content-Type' => 'text/plain' },
      f
    ]
  when %r{\A/blob/}
    [ 200,
      [%w(Content-Length 5), %w(Content-Type text/plain)],
      Blob.new(env)
    ]
  else
    [ 404, [%w(Content-Length 0), %w(Content-Type text/plain)], [] ]
  end
})
