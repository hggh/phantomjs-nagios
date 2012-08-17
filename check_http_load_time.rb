#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'time'
require 'optparse'
require 'timeout'

options = {}
options[:phantomjs_bin] = "/usr/bin/phantomjs"
options[:phantomjs_opts] = "--load-images=yes --local-to-remote-url-access=yes --disk-cache=no --ignore-ssl-errors=yes"
options[:snifferjs] = "netsniff.js"
options[:warning]   = 1.0
options[:critical]  = 2.0
options[:html] = false

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
	opts.on("-e", "--html", "Add html tags to output url") do |e|
		options[:html] = true
	end
end.parse!

unless File.executable?(options[:phantomjs_bin])
	puts "Could not find PhantomJS binary (#{options[:phantomjs_bin]})"
	exit 3
end

website_url = URI(options[:url])
website_load_time = 0.0

# Run Phantom
output = ""
begin
	Timeout::timeout(options[:critical].to_i) do
		@pipe = IO.popen(options[:phantomjs_bin] + " " + options[:phantomjs_opts]  + " " + options[:snifferjs] + " " + website_url.to_s + " 2> /dev/null")
		output = @pipe.read
		Process.wait(@pipe.pid)
	end
rescue Timeout::Error => e
	puts "Critical: #{website_url.to_s} PhantomJS takes too long"
	Process.kill(9, @pipe.pid)
	Process.wait(@pipe.pid)
	exit 2
end

begin
	hash = JSON.parse(output)
rescue
	puts "Unkown: Could not parse JSON from phantomjs"
	exit 3
end

request_global_time_start = Time.iso8601(hash['log']['pages'][0]['startedDateTime'])
request_global_time_end   = Time.iso8601(hash['log']['pages'][0]['endedDateTime'])
request_size = hash['log']['pages'][0]['size']
request_count = hash['log']['pages'][0]['resourcesCount']

website_load_time = '%.2f' % (request_global_time_end - request_global_time_start)
website_load_time_ms = (request_global_time_end - request_global_time_start) * 1000

performance_data = " | load_time=#{website_load_time_ms.to_s}ms size=#{request_size} requests=#{request_count.to_s}"

website_url_info = website_url.to_s
if options[:html]
	website_url_info = "<a href='" + website_url.to_s + "'>" + website_url.to_s + "</a>"
end

if website_load_time.to_f > options[:critical].to_f
	puts "Critical: #{website_url_info} load time: #{website_load_time.to_s}" + performance_data
	exit 2
elsif website_load_time.to_f > options[:warning].to_f
	puts "Warning: #{website_url_info} load time: #{website_load_time.to_s}" + performance_data
	exit 1
else
	puts "OK: #{website_url_info} load time: #{website_load_time.to_s}" + performance_data
	exit 0
end

