require 'rubygems'
require 'httparty'
require "thor"
require 'susuwatari'
require_relative 'lib/web_page_test_location'
require_relative 'lib/google/spreadsheet'

class WebPageTest < Thor
  class_option :api_key, :aliases => :a, :required => true
  class_option :location, :aliases => :l, :required => true
  class_option :view, :aliases => :v, :required => true
  class_option :google_username, :aliases => :u
  class_option :google_password, :aliases => :p
  class_option :google_spreadsheet_key, :aliases => :k

  METRICS = [:ttfb, :render, :load_time, :visual_complete, :fully_loaded, :speed_index]

  include Google

  desc "wpt_analyze", "Analyze a website with WePageTest.org"

  def wpt_analyze(url)
    wptl = WebPageTestLocation.new
    wptl_open = wptl.is_open?(options[:location])
    raise "Unable to open #{options[:location]}" unless wptl_open
    wpt = Susuwatari.new(url: url, k: options[:api_key], location: options[:location], video: 1)
    wpt.run
    while wpt.status.eql?(:running)
      sleep 5 # seconds
      printf "."
    end
    puts
    if wpt.respond_to?(:result)
      location = options[:location].split(/[:_]/)
      browser = location.last
      location = location.first
      prefix = "#{options[:view].gsub(/\s+/, "_")}.#{browser}.#{location}"
      cells = [
          Time.now.to_s,
          Date.today.strftime('%A'),
          nil
      ]
      if wpt.respond_to?(:result)
        if wpt.result.run.first_view.respond_to?(:results)
          METRICS.each do |metric|
            cells << (wpt.result.run.first_view.results.send(metric).to_f / 1000).to_s if spreadsheet?
            puts("#{prefix}.first_view.#{metric} = #{wpt.result.run.first_view.results.send(metric)}ms")
          end
          cells << nil # spacer
        else
          7.times { cells << nil }
        end
        if wpt.result.run.repeat_view.respond_to?(:results)
          METRICS.each do |metric|
            cells << (wpt.result.run.repeat_view.results.send(metric).to_f / 1000).to_s if spreadsheet?
            puts("#{prefix}.repeat_view.#{metric} = #{wpt.result.run.repeat_view.results.send(metric)}ms")
          end
          cells << wpt.result.summary
        else
          7.times { cells << nil }
        end
      end
      cells.flatten!
      if spreadsheet?
        ss = Google::Spreadsheet.new(
            options[:google_spreadsheet_key],
            options[:google_username],
            options[:google_password])
        raise "Unable to open spreadsheet" if ss.nil?
        worksheet_name = "#{options[:view]}:#{options[:location]}"
        puts "Saving to Google Spreadsheet, tab #{worksheet_name}"
        ws = ss.use_worksheet_called(worksheet_name)
        ws ||= ss.add_worksheet(worksheet_name)
        ss.add_to_worksheet(ws, cells)
        ss.save_worksheet(ws)
        puts "Spreadsheet saved"
      end
    end
  end

  no_commands do
    def spreadsheet?
      if options[:google_username] || options[:google_password] || options[:google_spreadsheet_key]
        raise "Must specify all google options(google_username,google_password,google_spreadsheet_key) to save spreadsheet" unless options[:google_username] && options[:google_password] && options[:google_spreadsheet_key]
        true
      else
        false
      end
    end
  end
end

WebPageTest.start(ARGV)