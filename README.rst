Nagios load test for Websites
=============================

This Nagios/Icinga plugin measure the complete load of an website.

PhantomJS - headless WebKit
+++++++++++++++++++++++++++

This Nagios plugin uses `PhantomJS`_ for testing the load time. PhantomJS
downloads and render the website as you are doing it with Firefox.

This test fetchs also all images/css/js files.

Command line
++++++++++++

- -u http://www.fahrrad.de/
- -c 2.0 ``[second]``
- -w 1.0 ``[second]``
- -e

requirements to run phantomjs-nagios
++++++++++++++++++++++++++++++++

 - ruby 1.8
 - ruby-json
 - PhantomJS 1.6 or higher (check_http_load_time.rb does not support Xvfb)

run check
+++++++++
	check_http_load_time.rb -u http://www.fahrrad.de -w 1.9 -c 2.5 -e

	OK: <a href='http://www.fahrrad.de'>http://www.fahrrad.de</a> load time: 1.78 | load_time=1776.0ms size=591152 requests=99 dom_elements=997

Nagios/Icinga performance data
++++++++++++++++++++++++++++++

- load_time: load time of complete website in ms
- size: complete size of all downloaded files in byte
- requests: count of files (css,js,html,...)
- dom_elements: count of all DOM elements on the site

Contact?
++++++++
Jonas Genannt / http://blog.brachium-system.net

.. _PhantomJS: http://www.phantomjs.org/
