# -*- encoding: binary -*-
# :enddoc:

RUBY_VERSION =~ %r{\A1\.8} and
  warn "Coolio and Threads do not mix well under Ruby 1.8"

class Rainbows::Coolio::ThreadClient < Rainbows::Coolio::Client
  def app_call input
    KATO.delete(self)
    disable if enabled?
    @env[RACK_INPUT] = input
    app_dispatch # must be implemented by subclass
  end

  # this is only called in the master thread
  def response_write(response)
    ev_write_response(*response, @hp.next?)
    rescue => e
      handle_error(e)
  end

  # fails-safe application dispatch, we absolutely cannot
  # afford to fail or raise an exception (killing the thread)
  # here because that could cause a deadlock and we'd leak FDs
  def app_response
    begin
      @env[REMOTE_ADDR] = @_io.kgio_addr
      APP.call(@env.merge!(RACK_DEFAULTS))
    rescue => e
      Rainbows::Error.app(e) # we guarantee this does not raise
      [ 500, {}, [] ]
    end
  end
end
