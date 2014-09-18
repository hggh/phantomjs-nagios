if (!Date.prototype.toISOString) {
    Date.prototype.toISOString = function () {
        function pad(n) { return n < 10 ? '0' + n : n; }
        function ms(n) { return n < 10 ? '00'+ n : n < 100 ? '0' + n : n }
        return this.getFullYear() + '-' +
            pad(this.getMonth() + 1) + '-' +
            pad(this.getDate()) + 'T' +
            pad(this.getHours()) + ':' +
            pad(this.getMinutes()) + ':' +
            pad(this.getSeconds()) + '.' +
            ms(this.getMilliseconds()) + 'Z';
    }
}

function createHAR(address, title, startTime, resources, endTime, dom_element_count)
{
   var bodySize = 0;
   resources.forEach(function (resource) {
   var request = resource.request,
                 startReply = resource.startReply,
                 endReply = resource.endReply;
      if (!request || !startReply || !endReply) {
         return;
      }
      bodySize = bodySize + startReply.bodySize;
   });
   // the first element of the resouces arry should be the request, so we track the load time
   var resource_initial_load_time = 0;
   if (resources[1] ) {
      resource_initial_load_time = resources[1].endTime - resources[1].startTime;
   }
   return {
      log: {
            version: '1.2',
            creator: {
                name: "PhantomJS",
                version: phantom.version.major + '.' + phantom.version.minor +
                    '.' + phantom.version.patch
            },
            pages: [{
               startedDateTime: startTime.toISOString(),
               endedDateTime: endTime.toISOString(),
               initialResourceLoadTime: resource_initial_load_time,
               id: address,
               size: bodySize,
               resourcesCount: resources.length,
               domElementsCount: dom_element_count,
               title: title,
               jscheck: page.jscheck,
               jscheckout: page.jscheckout,
               pageTimings: {}
            }],
         }
   };
}

var page = require('webpage').create(),
    system = require('system');
page.viewportSize = { width: 1600, height: 1200 };

if (system.args.length === 1) {
   console.log('Usage: netsniff.js <some URL>');
   phantom.exit();
}
else {
   page.address = system.args[1];
   page.jscheck = system.args[2];
   page.settings.userAgent = 'hggh PhantomJS Webspeed Test';

   page.resources = [];

   page.onLoadStarted = function () {
      page.startTime = new Date();
   };

   // PhantomJS outputs error, throw errors any. it will break json
   page.onError = function (message, trace) {
   };

   page.onResourceRequested = function (req) {
      page.resources[req.id] = {
         request: req,
         startTime: new Date(),
         startReply: null,
         endReply: null
      };
   };

   page.onResourceReceived = function (res) {
      if (res.stage === 'start') {
         page.resources[res.id].startReply = res;
      }
      if (res.stage === 'end') {
         page.resources[res.id].endReply = res;
         page.resources[res.id].endTime = new Date();
      }
   };

   page.onLoadFinished = function (status) {
      var har;
      var dom_element_count = page.evaluate(function (s) {
         return document.getElementsByTagName('*').length;
      });
      page.jscheckout = page.evaluate(function (){return eval(arguments[0]);},page.jscheck);
      har = createHAR(page.address, page.title, page.startTime, page.resources, new Date(), dom_element_count);
      console.log(JSON.stringify(har, undefined, 4));
      phantom.exit();
   };
   page.open(page.address);
}
