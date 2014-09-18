#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'time'
require 'optparse'
require 'timeout'

options = {}
options[:url] = ""
options[:phantomjs_bin] = "/usr/bin/phantomjs"
options[:phantomjs_opts] = "--load-images=yes --local-to-remote-url-access=yes --disk-cache=no"
options[:phantomjs_extra_ops] = [ ]
options[:snifferjs] = File.join(File.dirname(__FILE__), "netsniff.js")
options[:warning]   = 1.0
options[:critical]  = 2.0
options[:html] = false
options[:request_range] = false
options[:size] = false 
options[:domelemets] = false 
options[:perf] = false
options[:verbosity] = 0
options[:jscheck] = false
exitcode = 0
output = ""

# Sets the Exit code, as an exitcode may only be increased and not decreased
def setExit(code, prevcode)
  if code <= prevcode
    return prevcode
  elsif code > prevcode
    return code
  end
end

# Argument parser
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-u", "--url [STRING]", "URL to query" ) do |u|
    options[:url] = u
  end
  opts.on("-w", "--warning [FLOAT]", "Time when warning") do |w|
    options[:warning] = w
  end
  opts.on("-c", "--critical [FLOAT]", "Time when critical") do |c|
    options[:critical] = c
  end
  opts.on("-p", "--phantomjs [PATH]", "Path to PhantomJS binary (default: #{options[:phantomjs_bin]})") do |p|
    options[:phantomjs_bin] = p
  end
  opts.on("-n", "--netsniff [PATH]", "Path to netsniff.js script (default: #{options[:snifferjs]})") do |n|
    options[:snifferjs] = n
  end
  opts.on("-e", "--html", "Add html tags to output url") do
    options[:html] = true
  end
        opts.on("-j", "--jscheck [STRING]", "Js check to eval") do |j|
                options[:jscheck] = j
        end
  opts.on("-l", "--ps-extra-opts [STRING]", "Extra PhantomJS Options (default: no options) [eg -l 'debug' -l 'proxy=localhost']") do |l|
    options[:phantomjs_extra_ops] << "--" + l.to_s
  end
  opts.on("-r", "--request [RANGE]", "Check if requests is in range [50:100] (default: not checked)") do |r|
    begin
      if r =~ /^(\d+):(\d+)$/ and $1.to_i < $2.to_i
        options[:request_range] = [ $1.to_i, $2.to_i ]
      else
        raise
      end
    rescue
      puts "Please use [-r|-request] 50:100"
      setExit(3, exitcode)
      exit exitcode
    end
  end
  opts.on("-s", "--size [RANGE]", "Check if the size of the site is in range [1:20000] (default: not checked)") do |s|
    begin
      if s =~ /^(\d+):(\d+)$/ and $1.to_i < $2.to_i 
        options[:size] = [ $1.to_i, $2.to_i ]
      else
        raise
      end
    rescue
      puts "Please use [-s|--size] min:max"
      exitcode = setExit(3, exitcode)
      exit exitcode
    end
  end
  opts.on("-d", "--domelemets [RANGE]", "Check if the number of the site dom elements is in range [1:20000] (default: not checked)") do |s|
    begin
      if s =~ /^(\d+):(\d+)$/ and $1.to_i < $2.to_i 
        options[:domelemets] = [ $1.to_i, $2.to_i ]
      else
        raise
      end
    rescue
      puts "Please use [-d|--domelemets] min:max"
      exitcode = setExit(3, exitcode)
      exit exitcode
    end
  end
  opts.on("-P", "--perf", "Add performance Data (default: no)") do
    options[:perf] = true
  end
  opts.on("-v", "--verbose [n]", "Verbose Output (Valid Inputs [1-3]. For more information see: https://www.nagios-plugins.org/doc/guidelines.html#AEN41)") do |v|
    options[:verbosity] = ( v || 1).to_i
  end

end.parse!

unless File.executable?(options[:phantomjs_bin])
  puts "UNKOWN: Could not find PhantomJS binary (#{options[:phantomjs_bin]})"
  exitcode = setExit(3, exitcode)
  exit exitcode
end

if options[:url] == ""
  puts "UNKNOWN: No URL given!"
  exitcode = setExit(3, exitcode)
  exit exitcode
end

website_url = URI(options[:url])
website_load_time = 0.0
# Warning may not be greater than crit
if options[:warning].to_f > options[:critical].to_f
  puts "UNKOWN: Warning timeout (#{options[:warning].to_f}s) may not be greater than Critical timeout (#{options[:critical].to_f}s)"
  exitcode = setExit(3, exitcode)
  exit exitcode
end
# Run Phantom
begin
  Timeout::timeout(options[:critical].to_i + 3) do
    cmd = Array.new
    cmd << options[:phantomjs_bin]
    cmd << options[:phantomjs_opts]
    cmd << options[:phantomjs_extra_ops]
    cmd << options[:snifferjs]
    cmd << website_url.to_s
    cmd << "'#{options[:jscheck]}'"
    cmd << "2> /dev/null"
    warn "PhantomJS cmd is: " + cmd.join(" ") if options[:verbosity].to_i == 3
    @pipe = IO.popen(cmd.join(" "))
    output = @pipe.read
    Process.wait(@pipe.pid)
  end
rescue Timeout::Error => e
  critical_time_ms = options[:critical].to_i * 1000
  puts "CRITICAL: #{website_url.to_s}: Timeout after: #{options[:critical]} | load_time=#{critical_time_ms.to_s}"
  Process.kill(9, @pipe.pid)
  Process.wait(@pipe.pid)
  exitcode = setExit(2, exitcode)
  exit 
end

# Debug output
begin
  warn "JSON Output:\n" + output if options[:verbosity] == 3
  hash = JSON.parse(output)
rescue
  puts "UNKNOWN: Could not parse JSON from phantomjs"
  exit 3
end

# Calculating Time, Size and Requests
request_global_time_start = Time.iso8601(hash['log']['pages'][0]['startedDateTime'])
request_global_time_end   = Time.iso8601(hash['log']['pages'][0]['endedDateTime'])
request_size = hash['log']['pages'][0]['size']
request_count = hash['log']['pages'][0]['resourcesCount'].to_i
dom_element_count = hash['log']['pages'][0]['domElementsCount'].to_i
website_load_time_initial_request = hash['log']['pages'][0]['initialResourceLoadTime'].to_i
jscheck = hash['log']['pages'][0]['jscheckout'].to_s
website_load_time = '%.2f' % (request_global_time_end - request_global_time_start)
website_load_time_ms = (request_global_time_end - request_global_time_start) * 1000
website_url_info = website_url.to_s

if options[:html]
  website_url_info = "<a href='" + website_url.to_s + "'>" + website_url.to_s + "</a>"
end
# Outputs without Errors (normal output + performance data)
performance_data = " | load_time=#{website_load_time_ms.to_s}ms size=#{request_size} requests=#{request_count.to_s} dom_elements=#{dom_element_count.to_s} load_time_initial_req=#{website_load_time_initial_request.to_s}ms"
output = "#{website_url_info} load time: #{website_load_time.to_s}"


if options[:jscheck] and (jscheck != 'true')
        if options[:verbosity] == 1
                output = output + " (Jscheck: #{options[:jscheck]})"
        elsif options[:verbosity] >= 2
                output = output + " (Jscheck doesn equal true : #{options[:jscheck]})"
        else
                output = output + " Jscheck."
        end
        exitcode = setExit(1, exitcode)
     
end
# Load time Warning
if website_load_time.to_f > options[:warning].to_f and website_load_time.to_f < options[:critical].to_f
  if options[:verbosity] == 1
    output = output + " (Load: #{options[:warning]}s)"
  elsif options[:verbosity] >= 2
    output = output + " (Load time warning: #{options[:warning]}s)"
  else
    output = output + " Load warn."
  end
  exitcode = setExit(1, exitcode)
end

# Load time Critical
if website_load_time.to_f > options[:critical].to_f
  if options[:verbosity] == 1
    output = output + " (Load: #{options[:critical]}s)"
  elsif options[:verbosity] >= 2
    output = output + " (Load time critical: #{options[:critical]}s)"
  else
    output = output + " Load crit."
  end
  exitcode = setExit(2, exitcode)
end

# Amount of requests critical
if options[:request_range] and !request_count.between?(options[:request_range][0], options[:request_range][1])
  if options[:verbosity] == 1
    output = output + " (Req: #{options[:request_range][0]}:#{options[:request_range][1]})"
  elsif options[:verbosity] >= 2
    output = output + " (Requests cirtical: #{options[:request_range][0]}:#{options[:request_range][1]})"
  else
    output = output + " Req. Crit."
  end
  exitcode = setExit(2, exitcode)
end

# Site size Critical
if options[:size] and !request_size.between?(options[:size][0], options[:size][1])
  if options[:verbosity] == 1
    output = output + " (Size: #{options[:size][0]}:#{options[:size][1]})"
  elsif options[:verbosity] >= 2
    output = output + " (Size critical: #{options[:size][0]}:#{options[:size][1]})"
  else
    output = output + " Size crit."
  end
  exitcode = setExit(2, exitcode)
end

# Site Dom elemets Critical
if options[:domelemets] and !dom_element_count.between?(options[:domelemets][0], options[:domelemets][1])
  if options[:verbosity] == 1
    output = output + " (domelemets: #{options[:domelemets][0]}:#{options[:domelemets][1]})"
  elsif options[:verbosity] >= 2
    output = output + " (Domelemets critical: #{options[:domelemets][0]}:#{options[:domelemets][1]})"
  else
    output = output + " Domelemets crit."
  end
  exitcode = setExit(2, exitcode)
end

if exitcode == 0
  output = "OK: " + output
elsif exitcode == 1
  output = "WARNING: " + output
elsif exitcode == 2
  output = "CRITICAL: " + output
end
if options[:perf] == true
  output = output + performance_data
end
# Final Output
puts output
exit exitcode
