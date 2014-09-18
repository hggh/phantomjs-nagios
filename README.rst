Nagios load test for Websites
=============================

This Nagios/Icinga plugin measure the complete load of an website.

PhantomJS - headless WebKit
+++++++++++++++++++++++++++

This Nagios plugin uses `PhantomJS`_ for testing the load time. PhantomJS
load and render the website as you are doing it with browser.

Command line
++++++++++++

- -u, --url [STRING]
- -w, --warning [FLOAT]
- -c, --critical [FLOAT]
- -p, --phantomjs [PATH]
- -n, --netsniff [PATH]
- -e, --html
- -j, --jscheck [STRING]
- -l, --ps-extra-opts [STRING]
- -r, --request [RANGE]
- -s, --size [RANGE]
- -d, --domelemets [RANGE]
- -P, --perf
- -v, --verbose [n]


PhantomJS Options
+++++++++++++++++

You can pass-through options from the check_http_load_time.rb to PhantomJS.

Use the -l flag. (eg. -l 'proxy=localhost' for proxy settings on PhantomJS)

Tracking / Social Media on website slows down
+++++++++++++++++++++++++++++++++++++++++++++

If you have social media / tracking stuff on you site that you are monitoring it
could slow down or alert your site if third party is offline.

You can ignore hosts with an patch from Jonas Genannt.

See: http://code.google.com/p/phantomjs/issues/detail?id=230

Patch: https://github.com/hggh/phantomjs/compare/ignore-host.patch

Afer installing PhantomJS with that patch use:

	-l "ignore-host='(google.com|twitter.com)'

requirements to run phantomjs-nagios
++++++++++++++++++++++++++++++++

- ruby
- json
- PhantomJS 1.9 or higher (check_http_load_time.rb does not support Xvfb)

run check
+++++++++
	check_http_load_time.rb --perf -c 3 -w 2 -u http://www.fahrrad.de

	OK: http://www.fahrrad.de load time: 1.59 | load_time=1590.0ms size=1058140 requests=105 dom_elements=1319 load_time_initial_req=93ms

Nagios/Icinga performance data
++++++++++++++++++++++++++++++

- load_time: load time of complete website in ms
- size: complete size of all downloaded files in byte
- requests: count of files (css,js,html,...)
- dom_elements: count of all DOM elements on the site
- load_time_initial_req: the load time of the first request

Contact?
++++++++
Jonas Genannt / http://blog.brachium-system.net

.. _PhantomJS: http://www.phantomjs.org/
