require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'em-http-request'
require 'eventmachine'
require 'multi_json'

module Sensu::Extension
  class History < Bridge
    def name
      definition[:name]
    end

    def definition
      {
        type: 'extension',
        name: 'history'
      }
    end

    def description
      'Sends check result data to influxdb'
    end

    def post_init()
      @influx_conf = parse_settings
      logger.info("InfluxDB history extension initialiazed using #{@influx_conf['protocol'] }://#{ @influx_conf['host'] }:#{ @influx_conf['port'] } - Defaults : db=#{@influx_conf['database']} precision=#{@influx_conf['time_precision']}")

      @relay = InfluxRelay.new
      @relay.init(@influx_conf)

      logger.info("History write buffer initiliazed : buffer flushed every #{@influx_conf['buffer_max_size']} points OR every #{@influx_conf['buffer_max_age']} seconds) ")
    end

    def run(event_data)
      if event_data[:check][:type] != 'check' then
        yield '', 0
        return
      end

      host = event_data[:client][:name].split('.')[0]
      metric = event_data[:check][:name]
      timestamp = event_data[:check][:executed]
      value = if event_data[:check][:status] == 0 then 1 else 0 end
      output = "#{@influx_conf['scheme']}.#{host}.checks.#{metric} value=#{value} #{timestamp}"

      @relay.push(@influx_conf['database'], @influx_conf['time_precision'], output)
      yield output, 0
    end

    def stop
      logger.info('Flushing history buffer before exiting')
      @relay.flush_buffer
      true
    end

    private

    def parse_settings()
      begin
        settings = @settings['history']

        # default values
        settings['tags'] ||= {}
        settings['use_ssl'] ||= false
        settings['time_precision'] ||= 's'
        settings['protocol'] = settings['use_ssl'] ? 'https' : 'http'
        settings['buffer_max_size'] ||= 500
        settings['buffer_max_age'] ||= 6 # seconds
        settings['port'] ||= 8086
        settings['scheme'] ||= 'sensu'

      rescue => e
        logger.error("Failed to parse History settings #{e}")
      end
      return settings
    end

    def logger
      Sensu::Logger.get
    end
  end
end
