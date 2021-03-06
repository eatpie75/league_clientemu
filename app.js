// Generated by CoffeeScript 1.9.0
(function() {
  var child_process, get_matches, get_running, main, os, running, servers, start_server,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  child_process = require('child_process');

  servers = require('./settings.json').servers;

  os = require('os');

  process.chdir(__dirname);

  running = [];

  main = function() {
    var index, server, _i, _len, _ref, _results;
    index = 0;
    _results = [];
    for (_i = 0, _len = servers.length; _i < _len; _i++) {
      server = servers[_i];
      if (_ref = server.region + ":" + server.username, __indexOf.call(running, _ref) < 0) {
        start_server(index);
      } else {
        console.log(server.region + ":" + server.username + " already running");
      }
      _results.push(index += 1);
    }
    return _results;
  };

  start_server = function(index) {
    var tmp;
    tmp = child_process.spawn(process.execPath, [__dirname + '/bridge.js', index], {
      'cwd': __dirname,
      'detached': true,
      'stdio': 'ignore'
    });
    return tmp.unref();
  };

  get_matches = function(string, regex, index) {
    var match, matches;
    if (index == null) {
      index = 1;
    }
    matches = [];
    while (match = regex.exec(string)) {
      matches.push(match[index]);
    }
    return matches;
  };

  get_running = function() {
    return child_process.exec('pgrep bridge.js -l -f', function(error, stdout, stderr) {
      var r;
      r = /\d{1,6} bridge\.js: (\w*:\S*)/gim;
      running = get_matches(stdout, r);
      return main();
    });
  };

  if (os.platform() === 'linux') {
    get_running();
  } else {
    main();
  }

}).call(this);
