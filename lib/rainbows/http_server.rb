# -*- encoding: binary -*-
# :enddoc:

class Rainbows::HttpServer < Unicorn::HttpServer
  def self.setup(block)
    Rainbows.server.instance_eval(&block)
  end

  def initialize(app, options)
    Rainbows.server = self
    @logger = Unicorn::Configurator::DEFAULTS[:logger]
    rv = super(app, options)
    defined?(@use) or use(:Base)
    @worker_connections ||= Rainbows::MODEL_WORKER_CONNECTIONS[@use]
  end

  def reopen_worker_logs(worker_nr)
    logger.info "worker=#{worker_nr} reopening logs..."
    Unicorn::Util.reopen_logs
    logger.info "worker=#{worker_nr} done reopening logs"
    rescue
      Rainbows.quit! # let the master reopen and refork us
  end

  # Add one second to the timeout since our fchmod heartbeat is less
  # precise (and must be more conservative) than Unicorn does.  We
  # handle many clients per process and can't chmod on every
  # connection we accept without wasting cycles.  That added to the
  # fact that we let clients keep idle connections open for long
  # periods of time means we have to chmod at a fixed interval.
  def timeout=(nr)
    @timeout = nr + 1
  end

  def load_config!
    use :Base
    Rainbows.keepalive_timeout = 5
    Rainbows.max_bytes = 1024 * 1024
    @worker_connections = nil
    super
    @worker_connections ||= Rainbows::MODEL_WORKER_CONNECTIONS[@use]
  end

  def ready_pipe=(v)
    # hacky hook got force Rainbows! to load modules only in workers
    if defined?(@master_pid) && @master_pid == Process.ppid
      extend(Rainbows.const_get(@use))
    end
    super
  end

  def use(*args)
    model = args.shift or return @use
    mod = begin
      Rainbows.const_get(model)
    rescue NameError => e
      logger.error "error loading #{model.inspect}: #{e}"
      e.backtrace.each { |l| logger.error l }
      raise ArgumentError, "concurrency model #{model.inspect} not supported"
    end

    Module === mod or
      raise ArgumentError, "concurrency model #{model.inspect} not supported"
    args.each do |opt|
      case opt
      when Hash; Rainbows::O.update(opt)
      when Symbol; Rainbows::O[opt] = true
      else; raise ArgumentError, "can't handle option: #{opt.inspect}"
      end
    end
    mod.setup if mod.respond_to?(:setup)
    new_defaults = {
      'rainbows.model' => (@use = model.to_sym),
      'rack.multithread' => !!(model.to_s =~ /Thread/),
      'rainbows.autochunk' => [:Coolio,:Rev,:Epoll,:XEpoll,
                               :EventMachine,:NeverBlock].include?(@use),
    }
    Rainbows::Const::RACK_DEFAULTS.update(new_defaults)
  end

  def worker_connections(*args)
    return @worker_connections if args.empty?
    nr = args[0]
    (Integer === nr && nr > 0) or
      raise ArgumentError, "worker_connections must be a positive Integer"
    @worker_connections = nr
  end

  def keepalive_timeout(nr)
    (Integer === nr && nr >= 0) or
      raise ArgumentError, "keepalive_timeout must be a non-negative Integer"
    Rainbows.keepalive_timeout = nr
  end

  def keepalive_requests(nr)
    Integer === nr or
      raise ArgumentError, "keepalive_requests must be a non-negative Integer"
    Unicorn::HttpRequest.keepalive_requests = nr
  end

  def client_max_body_size(nr)
    err = "client_max_body_size must be nil or a non-negative Integer"
    case nr
    when nil
    when Integer
      nr >= 0 or raise ArgumentError, err
    else
      raise ArgumentError, err
    end
    Rainbows.max_bytes = nr
  end
end
