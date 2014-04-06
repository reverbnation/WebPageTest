require 'httparty'

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
