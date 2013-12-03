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

function outputjson(address, title, startTime, resources, endTime, dom_element_count)
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
  jsonobj = {
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
        domElementsCount: dom_element_count,
        title: title,
        jscheck: page.jscheck,
        jscheckout: page.jscheckout,
        error: page.error
      }],
    }
  }
  console.log(JSON.stringify(jsonobj, undefined, 4));
  phantom.exit();
}

if (phantom.args.length === 0) {
  //If we don't have any args die
  console.log('Usage: netsniff.js <some URL> <jscheck>');
  phantom.exit();
}

var page = new WebPage(), output;
page.error = false
page.viewportSize = { width: 1600, height: 1200 };

page.address = phantom.args[0];
page.jscheck = phantom.args[1];
page.settings.userAgent = 'hggh PhantomJS Webspeed Test';

page.resources = [];

page.onLoadStarted = function () {
  page.startTime = new Date();
};

// PhantomJS outputs error
function errorfunction (message, trace) {
  page.error = message
  outputjson(page.address, page.title, page.startTime, page.resources, new Date(), 0);
}


page.onError = function (message, trace) { errorfunction(message, trace) }
phantom.onError = function (mesage, trace) { errorfunction(message, trace) }
page.onResourceError = function (message) { errorfunction(message,'') }

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
  if ( status === 'success' ){
    var dom_element_count = page.evaluate(function (s) {
      return document.getElementsByTagName('*').length;
    });
    page.jscheckout = page.evaluate(function (){return eval(arguments[0])},page.jscheck);
    outputjson(page.address, page.title, page.startTime, page.resources, new Date(), dom_element_count);
  }
  else
  {
    errorfunction( status, '' )
  }
};
//load the page
page.open(page.address)
