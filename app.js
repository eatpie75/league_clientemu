// Generated by CoffeeScript 1.3.3
(function() {
  var app, bind_events, child_process, clients, colors, express, http, lolclient_middleware, lolclient_status_middleware, options, path, routes, server, servers, tmp, _log;

  child_process = require('child_process');

  colors = require('colors');

  express = require('express');

  http = require('http');

  path = require('path');

  routes = require('./routes');

  clients = [];

  _log = function(msg) {
    var blank, d, info, time;
    blank = '                                                 ';
    d = new Date();
    time = (" " + (d.getFullYear()) + "/" + (d.getMonth() + 1) + "/" + (d.getDate()) + " " + (d.getHours()) + ":" + (d.getMinutes() < 10 ? '0' + d.getMinutes() : d.getMinutes()) + ":" + (d.getSeconds() < 10 ? '0' + d.getSeconds() : d.getSeconds())).white;
    info = (msg.server + time + blank).slice(0, 49);
    return console.log(info + " | " + msg.text);
  };

  lolclient_middleware = function(req, res, next) {
    req.lolclient = app.settings.lolclient;
    return next();
  };

  lolclient_status_middleware = function(req, res, next) {
    var client, data, _add_data, _i, _len, _results;
    data = [];
    _add_data = function(msg) {
      if (msg.event === 'status') {
        data.push({
          'server': msg.server,
          'data': msg.data
        });
      }
      if (data.length === clients.length) {
        req.lolclient_status = data;
        next();
      }
      return this.removeListener('message', _add_data);
    };
    _results = [];
    for (_i = 0, _len = clients.length; _i < _len; _i++) {
      client = clients[_i];
      client.on('message', _add_data);
      _results.push(client.send({
        event: 'status'
      }));
    }
    return _results;
  };

  bind_events = function(server) {
    return server.on('exit', function(code, signal) {
      return console.log(code, signal);
    }).on('message', function(msg) {
      if (msg.event === 'log') {
        return _log(msg);
      }
    });
  };

  servers = require('./servers.json');

  for (server in servers) {
    options = servers[server];
    tmp = child_process.fork('bridge.js');
    tmp.send({
      'event': 'connect',
      'options': options,
      'id': server
    });
    bind_events(tmp);
    clients.push(tmp);
  }

  app = express();

  app.configure(function() {
    app.set('port', process.env.PORT || 8080);
    app.set('lolclients', clients);
    app.use(express.logger('dev'));
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(express.compress());
    return app.use(app.router);
  });

  app.configure('development', function() {
    return app.use(express.errorHandler());
  });

  app.get('/status/', lolclient_status_middleware, routes.index);

  app.listen(app.settings.port, 'localhost');

}).call(this);