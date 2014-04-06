require 'httparty'
require 'rubygems'
require "thor"
require 'susuwatari'
require 'google_drive'

class WebPageTest < Thor
  class_option :api_key, :aliases => :a, :required => true
  class_option :location, :aliases => :l, :required => true
  class_option :view, :aliases => :v, :required => true
  class_option :google_username, :aliases => :u
  class_option :google_password, :aliases => :p
  class_option :google_spreadsheet_key, :aliases => :k

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
      if spreadsheet?
        session = GoogleDrive.login(options[:google_username], options[:google_password])
        ss = session.spreadsheet_by_key(options[:google_spreadsheet_key])
        raise "Unable to open spreadsheet" if ss.nil?
        worksheet_name = "#{options[:view]}:#{options[:location]}"
        puts "Saving to Google Spreadsheet, tab #{worksheet_name}"
        ws = get_worksheet_called(ss, worksheet_name)
        ws ||= add_worksheet(ss, worksheet_name)
        cells = [
            Time.now.to_s,
            Date.today.strftime('%A'),
            nil
        ]
        if wpt.respond_to?(:result)
          if wpt.result.run.first_view.respond_to?(:results)
            cells << [
                (wpt.result.run.first_view.results.ttfb.to_f / 1000).to_s,
                (wpt.result.run.first_view.results.render.to_f / 1000).to_s,
                (wpt.result.run.first_view.results.load_time.to_f / 1000).to_s,
                (wpt.result.run.first_view.results.visual_complete.to_f / 1000).to_s,
                (wpt.result.run.first_view.results.fully_loaded.to_f / 1000).to_s,
                (wpt.result.run.first_view.results.speed_index.to_f / 1000).to_s,
                nil
            ]
          else
            7.times { cells << nil }
          end
          if wpt.result.run.repeat_view.respond_to?(:results)
            cells << [
                (wpt.result.run.repeat_view.results.ttfb.to_f / 1000).to_s,
                (wpt.result.run.repeat_view.results.render.to_f / 1000).to_s,
                (wpt.result.run.repeat_view.results.load_time.to_f / 1000).to_s,
                (wpt.result.run.repeat_view.results.visual_complete.to_f / 1000).to_s,
                (wpt.result.run.repeat_view.results.fully_loaded.to_f / 1000).to_s,
                (wpt.result.run.repeat_view.results.speed_index.to_f / 1000).to_s,
                wpt.result.summary
            ]
          else
            7.times { cells << nil }
          end
        end
        cells.flatten!
        add_to_row(ws, cells)
        save_worksheet(ws)
        puts "Spreadsheet saved"
      else
        if wpt.result.run.first_view.respond_to?(:results)
          [:ttfb, :render, :load_time, :visual_complete, :fully_loaded, :speed_index].each do |metric|
            puts("#{prefix}.first_view.#{metric}=#{wpt.result.run.first_view.results.send(metric)}ms")
          end
        end
        if wpt.result.run.repeat_view.respond_to?(:results)
          [:ttfb, :render, :load_time, :visual_complete, :fully_loaded, :speed_index].each do |metric|
            puts("#{prefix}.repeat_view.#{metric}=#{wpt.result.run.repeat_view.results.send(metric)}ms")
          end
        end
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

    def get_worksheet_called(ss, title)
      ss.worksheets.detect{|w| w.title.eql?(title)}
    end

    def add_worksheet(ss, title)
      return ss.add_worksheet(title)
    end

    def duplicate_worksheet(ss, ws, title)
      old = ws.rows
      new = add_worksheet(ss, title)
      new.update_cells(1, 1, old)
      save_worksheet(new)
      new
    end

    def add_column(ws, name)
      column_place = ws.num_cols + 1
      ws[1, column_place] = name
      column_place
    end

    def last_row(ws)
      ws.num_rows + 1
    end

    def add_to_row(ws, array)
      last_row = last_row(ws)
      array.each_with_index do |a, i|
        ws[last_row, i + 1] = a
      end
    end

    def save_worksheet(ws)
      ws.save
    end

  end
end

class WebPageTestLocation
  include HTTParty
  attr_reader :json, :nodes, :browsers, :locations

  def initialize
    refresh
  end

  def nodes
    @nodes ||= @json.keys
  end

  def browsers
    @browsers ||= @json.map { |j| j.last["Browser"] }.uniq
  end

  def locations
    @locations ||= @json.map { |j| j.last["location"].split(/[:_]/).first }.uniq
  end

  def refresh
    @json = self.class.get("http://www.webpagetest.org/getLocations.php?f=json")["data"]
  end

  def open_executors
    @json.find_all { |j| j.last["PendingTests"]["Idle"] > 0 }
  end

  def is_open?(location)
    j = @json.select { |j| j.match(location) }
    raise "No location found for #{location}" if j.empty?
    j.values.first["PendingTests"]["Idle"] > 0 ? true : false
  end

  def find_open(regexp)
    nodes.find_all { |n| n.match(regexp) }.detect { |a| is_open?(a) }
  end

end

WebPageTest.start(ARGV)