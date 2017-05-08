require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'em-http-request'
require 'eventmachine'

module Sensu
  module Extension
    class InfluxRelay
      def init(config)
        @influx_conf = config
        @buffer = {}
        @flush_timer = EventMachine::PeriodicTimer.new(@influx_conf['buffer_max_age'].to_i) do
          unless buffer_size == 0
            flush_buffer
          end
        end
      end

      def flush_buffer
        logger.info('Flushing Buffer')
        @buffer.each do |db, tp|
          tp.each do |p, points|
            EventMachine::HttpRequest.new("#{@influx_conf['protocol']}://#{@influx_conf['host']}:#{@influx_conf['port']}/write?db=#{db}&precision=#{p}&u=#{@influx_conf['username']}&p=#{@influx_conf['password']}").post body: points.join("\n")
          end
          @buffer[db] = {}
        end
      end

      def buffer_size
        @buffer.map { |_db, tp| tp.map { |_p, points| points.length }.inject(:+) }.inject(:+) || 0
      end

      def push(database, time_precision, data)
        @buffer[database] ||= {}
        @buffer[database][time_precision] ||= []

        @buffer[database][time_precision].push(data)
        flush_buffer if buffer_size >= @influx_conf['buffer_max_size']
      end

      def logger
        Sensu::Logger.get
      end
    end
  end
end
