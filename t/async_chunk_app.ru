# based on async_examples/async_app.ru by James Tucker
class DeferrableChunkBody
  include EventMachine::Deferrable

  def call(*body)
    body.each do |chunk|
      @body_callback.call("#{chunk.size.to_s(16)}\r\n")
      @body_callback.call(chunk)
      @body_callback.call("\r\n")
    end
  end

  def each(&block)
    @body_callback = block
  end

  def finish
    @body_callback.call("0\r\n\r\n")
  end
end if defined?(EventMachine)

class AsyncChunkApp
  def call(env)
    headers = {
      'Content-Type' => 'text/plain',
      'Transfer-Encoding' => 'chunked',
    }
    delay = env["HTTP_X_DELAY"].to_i

    case env["rainbows.model"]
    when :EventMachine, :NeverBlock
      body = DeferrableChunkBody.new
      body.callback { body.finish }
      task = lambda {
        env['async.callback'].call([ 200, headers, body ])
        EM.add_timer(1) {
          body.call "Hello "

          EM.add_timer(1) {
            body.call "World #{env['PATH_INFO']}\n"
            body.succeed
          }
        }
      }
      delay == 0 ? EM.next_tick(&task) : EM.add_timer(delay, &task)
    when :Coolio
      # Cool.io only does one-shot responses due to the lack of the
      # equivalent of EM::Deferrables
      body = [ "Hello ", "World #{env['PATH_INFO']}\n", '' ].map do |chunk|
        "#{chunk.size.to_s(16)}\r\n#{chunk}\r\n"
      end

      next_tick = Coolio::TimerWatcher.new(delay, false)
      next_tick.on_timer { env['async.callback'].call([ 200, headers, body ]) }
      next_tick.attach(Coolio::Loop.default)
    else
      raise "Not supported: #{env['rainbows.model']}"
    end
    nil
  end
end
run AsyncChunkApp.new
