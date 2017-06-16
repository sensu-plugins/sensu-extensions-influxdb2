require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'em-http-request'
require 'eventmachine'
require 'multi_json'
require 'sensu/extension'
require 'sensu/extensions/influxdb/influx_relay'

module Sensu
  module Extension
    class InfluxDB < Handler
      def name
        definition[:name]
      end

      def definition
        {
          type: 'extension',
          name: 'influxdb'
        }
      end

      def description
        'Outputs metrics to InfluxDB'
      end

      def post_init
        @influx_conf = parse_settings
        logger.info("InfluxDB extension initialiazed using #{@influx_conf['protocol']}://#{@influx_conf['host']}:#{@influx_conf['port']} - Defaults : db=#{@influx_conf['database']} precision=#{@influx_conf['time_precision']}")

        @relay = InfluxRelay.new
        @relay.init(@influx_conf)

        logger.info("InfluxDB write buffer initiliazed : buffer flushed every #{@influx_conf['buffer_max_size']} points OR every #{@influx_conf['buffer_max_age']} seconds) ")
      end

      def run(event_data)
        event = parse_event(event_data)
        if event[:check][:status] != 0
          logger.error('Check status is not OK!')
          yield 'error', event[:check][:status]
          return
        end
        data = {}
        # init event and check data
        data[:client] = event[:client][:name]
        # This will merge : default conf tags < check embedded tags < sensu client/host tag
        data[:tags] = @influx_conf['tags'].merge(event[:check][:influxdb][:tags]).merge('host' => data[:client])
        # This will merge : check embedded templaes < default conf templates (check embedded templates will take precedence)
        data[:templates] = event[:check][:influxdb][:templates].merge(@influx_conf['templates'])
        data[:filters] = event[:check][:influxdb][:filters].merge(@influx_conf['filters'])
        event[:check][:influxdb][:database] ||= @influx_conf['database']
        event[:check][:time_precision] ||= @influx_conf['time_precision']
        event[:check][:influxdb][:strip_metric] ||= @influx_conf['strip_metric']
        data[:strip_metric] = event[:check][:influxdb][:strip_metric]
        data[:duration] = event[:check][:duration]
        event[:check][:output].split(/\r\n|\n/).each do |line|
          unless @influx_conf['proxy_mode'] || event[:check][:influxdb][:proxy_mode]
            data[:line] = line
            line = parse_line(data)
          end
          @relay.push(event[:check][:influxdb][:database], event[:check][:time_precision], line)
        end
        yield 'ok', 0
      end

      def stop
        logger.info('Flushing InfluxDB buffer before exiting')
        @relay.flush_buffer
        true
      end

      private

      def parse_event(event_data)
        event = MultiJson.load(event_data, symbolize_keys: true)

        # default values
        # n, u, ms, s, m, and h (default community plugins use standard epoch date)
        event[:check][:time_precision] ||= nil
        event[:check][:influxdb] ||= {}
        event[:check][:influxdb][:tags] ||= {}
        event[:check][:influxdb][:templates] ||= {}
        event[:check][:influxdb][:filters] ||= {}
        event[:check][:influxdb][:database] ||= nil
        event[:check][:influxdb][:proxy_mode] ||= false
        return event
      rescue => e
        logger.error("Failed to parse event data: #{e}")
      end

      def parse_settings
        settings = @settings['influxdb']

        # default values
        settings['tags'] ||= {}
        settings['templates'] ||= {}
        settings['filters'] ||= {}
        settings['use_ssl'] ||= false
        settings['use_basic_auth'] ||= false
        settings['proxy_mode'] ||= false
        settings['time_precision'] ||= 's'
        settings['protocol'] = settings['use_ssl'] ? 'https' : 'http'
        settings['buffer_max_size'] ||= 500
        settings['buffer_max_age'] ||= 6 # seconds
        settings['port'] ||= 8086
        return settings
      rescue => e
        logger.error("Failed to parse InfluxDB settings #{e}")
      end

      def strip_key(key, strip_metric, hostname)
        if strip_metric == 'host'
          slice_host(key, hostname)
        elsif strip_metric
          key.gsub(/^.*#{strip_metric}\.(.*$)/, '\1')
        end
      end

      def slice_host(slice, prefix)
        prefix.chars.zip(slice.chars).each do |char1, char2|
          break if char1 != char2
          slice.slice!(char1)
        end
        slice.slice!('.') if slice.chars.first == '.'
        slice
      end

      def get_name(arr1, arr2, pattern)
        pos = arr1.index { |s| s =~ /#{pattern}/ }
        if arr1[pos] =~ /\*$/
          arr2[pos...arr2.length].join('.')
        elsif arr1[pos] =~ /\d$/
          arr2[pos...arr1[pos].scan(/\d/).join.to_i + pos].join('.')
        else
          arr2[pos]
        end
      end

      def sanitize(str)
        str.gsub(',', '\,').gsub(/\s/, '\ ').gsub('"', '\"').gsub('\\') { '\\\\' }.delete('*').squeeze('.')
      end

      def parse_line(event)
        field_name = 'value'
        key, value, time = event[:line].split(/\s+/)

        # Apply filters
        event[:filters].each do |pattern, replacement|
          key.gsub!(/#{pattern}/, replacement)
        end

        # Strip metric name
        key = strip_key(key, event[:strip_metric], event[:client])

        # Sanitize key name
        key = sanitize(key)

        event[:templates].each do |pattern, template|
          next unless key =~ /#{pattern}/
          template = template.split('.')
          key = key.split('.')
          key_tags = if template.last =~ /\*$/ && !(template.last =~ /field/) && !(template.last =~ /measurement/)
                       key[0...template.length - 1] << key[template.length - 1...key.length].join('.')
                     else
                       key[0...template.length]
                     end

          field_name = get_name(template, key, 'field') if template.index { |s| s =~ /field/ }

          key = if template.index { |s| s =~ /measurement/ }
                  get_name(template, key, 'measurement')
                else
                  key[key_tags.length...key.length]
                end

          template.each_with_index do |tag, i|
            unless i >= key_tags.length || tag =~ /field/ || tag =~ /measurement/ || tag == 'void' || tag == 'null' || tag == 'nil'
              key += ",#{sanitize(tag)}=#{key_tags[i]}"
            end
          end
          break
        end

        # Append tags to measurement
        event[:tags].each do |tag, val|
          key += ",#{tag}=#{val}"
        end

        values = "#{field_name}=#{value.to_f}"
        values += ",duration=#{event[:duration].to_f}" if event[:duration]
        [key, values, time.to_i].join(' ')
      end

      def logger
        Sensu::Logger.get
      end
    end
  end
end
