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
    j = @json.select{|j| j.match(location) }
    raise Exception, "No location found!" if j.empty?
    j.values.first["PendingTests"]["Idle"] > 0 || j.values.first["PendingTests"]["Testing"] > 0
  end

  def is_too_busy?(location,queue_ratio=4)
    j = @json.select{|j| j.match(location) }
    raise Exception, "No location found!" if j.empty?
    return false if j.values.first["PendingTests"]["Idle"] > 0 #there are idle runners
    return false if j.values.first["PendingTests"]["Total"] == 0 #nothing is waiting
    return true if j.values.first["PendingTests"]["Testing"] == 0 #broke- jobs waiting, nothing is running and nothing idle
    (j.values.first["PendingTests"]["Total"]/j.values.first["PendingTests"]["Testing"]) > queue_ratio
  end

  def find_open(regexp)
    nodes.find_all { |n| n.match(regexp) }.detect { |a| is_open?(a) }
  end

end
