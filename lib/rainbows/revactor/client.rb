# -*- encoding: binary -*-
# :enddoc:
require 'fcntl'
class Rainbows::Revactor::Client
  autoload :TeeSocket, 'rainbows/revactor/client/tee_socket'
  RD_ARGS = {}
  Rainbows.keepalive_timeout > 0 and
    RD_ARGS[:timeout] = Rainbows.keepalive_timeout
  attr_reader :kgio_addr

  def initialize(client)
    @client, @rd_args, @ts = client, [ nil ], nil
    io = client.instance_variable_get(:@_io)
    io.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
    @kgio_addr = if Revactor::TCP::Socket === client
      @rd_args << RD_ARGS
      client.remote_addr
    else
      Kgio::LOCALHOST
    end
  end

  def kgio_read!(nr, buf)
    buf.replace(@client.read)
  end

  def write(buf)
    @client.write(buf)
  end

  def timed_read(buf2)
    buf2.replace(@client.read(*@rd_args))
  end

  def set_input(env, hp)
    env[RACK_INPUT] = 0 == hp.content_length ?
                      NULL_IO : IC.new(@ts = TeeSocket.new(@client), hp)
  end

  def to_io
    @client.instance_variable_get(:@_io)
  end

  def close
    @client.close
    @client = nil
  end

  def closed?
    @client.nil?
  end

  def self.setup
    self.const_set(:IC, Unicorn::HttpRequest.input_class)
    include Rainbows::ProcessClient
    include Methods
  end
end
require 'rainbows/revactor/client/methods'
