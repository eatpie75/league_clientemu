// Generated by CoffeeScript 1.4.0
(function() {
  var child_process, index, server, servers, tmp, _i, _len;

  child_process = require('child_process');

  servers = require('./settings.json').servers;

  index = 0;

  for (_i = 0, _len = servers.length; _i < _len; _i++) {
    server = servers[_i];
    tmp = child_process.spawn(process.execPath, ['bridge.js', index], {
      'detached': true,
      'stdio': 'ignore'
    });
    tmp.unref();
    index += 1;
  }

}).call(this);
