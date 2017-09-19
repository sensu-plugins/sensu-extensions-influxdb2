require File.join(File.dirname(__FILE__), 'helpers')
require 'sensu/extensions/influxdb2'
require 'socket'

describe 'Sensu::Extension::InfluxDB2' do
  include Helpers

  before do
    @extension = Sensu::Extension::InfluxDB2.new
    @extension.settings = {
      'influxdb' => {
        'database' => 'test',
        'host' => '127.0.0.1',
        'port' => 8087,
        'strip_metric' => 'rpsec_strip',
        'timeout' => 15,
        'buffer_max_size' => 1,
        'buffer_max_age' => 1
      }
    }
  end

  # it 'can run, returning raw event data' do
  #   async_wrapper do
  #     @extension.safe_run(event_template) do |output, status|
  #       expect(output).to eq('template')
  #       expect(status).to eq(0)
  #     end
  #   end
  # end
end
