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

function createHAR(address, title, startTime, resources, endTime)
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
               id: address,
               size: bodySize,
               resourcesCount: resources.length,
               title: title,
               pageTimings: {}
            }],
         }
   };
}

var page = new WebPage(), output;
page.viewportSize = { width: 1600, height: 1200 };

if (phantom.args.length === 0) {
   console.log('Usage: netsniff.js <some URL>');
   phantom.exit();
}
else {
   page.address = phantom.args[0];
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
      }
   };

   page.onLoadFinished = function (status) {
      var har;
      har = createHAR(page.address, page.title, page.startTime, page.resources, new Date());
      console.log(JSON.stringify(har, undefined, 4));
      phantom.exit();
   };
   page.open(page.address);
}
