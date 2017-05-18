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
          yield '', 0
          return
        end
        # init event and check data
        client = event[:client][:name]
        field_name = 'value'
        # This will merge : default conf tags < check embedded tags < sensu client/host tag
        tags = @influx_conf['tags'].merge(event[:check][:influxdb][:tags]).merge('host' => client)
        # This will merge : check embedded templaes < default conf templates (check embedded templates will take precedence)
        templates = event[:check][:influxdb][:templates].merge(@influx_conf['templates'])
        event[:check][:influxdb][:database] ||= @influx_conf['database']
        event[:check][:time_precision] ||= @influx_conf['time_precision']
        event[:check][:influxdb][:strip_metric] ||= @influx_conf['strip_metric']
        event[:check][:output].split(/\n/).each do |line|
          key, value, time = line.split(/\s+/)

          # Strip metric name
          key = strip_key(key, event[:check][:influxdb][:strip_metric], client)

          # Sanitize key name
          sanitize(key)

          templates.each do |pattern, template|
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
          tags.each do |tag, val|
            key += ",#{tag}=#{val}"
          end

          values = "#{field_name}=#{value.to_f}"
          values += ",duration=#{event[:check][:duration].to_f}" if event[:check][:duration]

          @relay.push(event[:check][:influxdb][:database], event[:check][:time_precision], [key, values, time.to_i].join(' '))
        end
        yield('', 0)
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
        event[:check][:influxdb][:database] ||= nil
        return event
      rescue => e
        logger.error("Failed to parse event data: #{e}")
      end

      def parse_settings
        settings = @settings['influxdb']

        # default values
        settings['tags'] ||= {}
        settings['templates'] ||= {}
        settings['use_ssl'] ||= false
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
          gsub(/^.*#{strip_metric}\.(.*$)/, '\1')
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

      def logger
        Sensu::Logger.get
      end
    end
  end
end
