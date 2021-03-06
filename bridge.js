// Generated by CoffeeScript 1.9.0
(function() {
  var af_app, app, bodyParser, bridge_status_middleware, child_process, client, client_exited, client_restart, compression, debug, express, http, id, initial, instance, logger, lolclient_middleware, methodOverride, mode, morgan, options, path, port, routes, server_id_middleware, server_list, start_client, status, version_override, version_override_data;

  child_process = require('child_process');

  express = require('express');

  http = require('http');

  path = require('path');

  routes = require('./routes');

  logger = require('./logger');

  debug = require('./settings.json').debug;

  morgan = require('morgan');

  bodyParser = require('body-parser');

  compression = require('compression');

  methodOverride = require('method-override');

  options = {};

  id = '';

  client = {};

  initial = true;

  status = {
    login_errors: 0,
    total_requests: 0,
    reconnects: 0,
    connected: false
  };

  version_override = false;

  version_override_data = '';

  if (process.env.VCAP_APPLICATION != null) {
    af_app = JSON.parse(process.env.VCAP_APPLICATION);
    instance = af_app.instance_index;
    port = process.env.VCAP_APP_PORT;
    mode = 'appfog';
    server_list = 'appfogsettings.json';
  } else {
    port = process.env.PORT || 8080;
    mode = 'normal';
    server_list = 'settings.json';
    instance = process.argv[2];
  }

  process.on('SIGTERM', function() {
    logger.warn("bridge: " + id + ": got SIGTERM");
    return process.exit(0);
  }).on('SIGUSR2', function() {
    logger.warn("bridge: " + id + ": get SIGUSR2, restarting client");
    client.removeListener('exit', client_exited);
    client.kill();
    return setTimeout(function() {
      return client_restart();
    }, 3000);
  });

  server_id_middleware = function(req, res, next) {
    req.server_id = id;
    return next();
  };

  lolclient_middleware = function(req, res, next) {
    req.lolclient = app.get('lolclient');
    return next();
  };

  bridge_status_middleware = function(req, res, next) {
    req.bridge_status = status;
    return next();
  };

  app = express();

  app.use(server_id_middleware);

  app.use(morgan({
    'format': 'tiny',
    'immediate': false,
    'stream': {
      'write': function(msg, enc) {
        return logger.info("http: " + id + ": " + (msg.slice(0, -1)));
      }
    }
  }));

  app.use(bodyParser());

  app.use(methodOverride());

  app.use(compression());

  app.use(function(err, req, res, next) {
    return res.send(500);
  });

  app.get('/status/', bridge_status_middleware, routes.status);

  app.get('/mass_update/', lolclient_middleware, routes.mass_update);

  app.get('/get_names/', lolclient_middleware, routes.get_names);

  app.get('/search/', lolclient_middleware, routes.search);

  app.get('/spectate/', lolclient_middleware, routes.spectate);

  app.get('/masterybook/', lolclient_middleware, routes.masterybook);

  logger.info("bridge: Preparing to connect");

  client_exited = function(code, signal) {
    var get_time;
    status.connected = false;
    if (debug) {
      logger.debug("bridge: " + id + ": client exit", [code, signal]);
    }
    if (code === 3 || code === 5) {
      logger.error("bridge: " + id + ": Client closed", {
        'code': code,
        'signal': signal
      });
      return setTimeout(client_restart, 2000);
    } else if (code === 1 || code === 4) {
      get_time = function() {
        var _ref, _ref1, _ref2;
        if (status.login_errors * 500 + 1000 <= 6000) {
          logger.info("bridge: " + id + ": restarting client in " + (status.login_errors * 500 + 1000) + "ms");
          return status.login_errors * 500 + 1000;
        } else if ((10 < (_ref = status.login_errors) && _ref < 20)) {
          logger.info("bridge: " + id + ": restarting client in 10s");
          return 10000;
        } else if ((20 <= (_ref1 = status.login_errors) && _ref1 < 30)) {
          logger.info("bridge: " + id + ": restarting client in 1m");
          return 60000;
        } else if ((30 <= (_ref2 = status.login_errors) && _ref2 < 40)) {
          logger.info("bridge: " + id + ": restarting client in 5m");
          return 300000;
        } else if (40 <= status.login_errors) {
          logger.info("bridge: " + id + ": restarting client in 10m");
          return 600000;
        }
      };
      status.login_errors += 1;
      return setTimeout(client_restart, get_time());
    } else if (signal === 'SIGABRT') {
      logger.error("bridge: " + id + ": Client closed", {
        'code': code,
        'signal': signal
      });
      return setTimeout(client_restart, 2000);
    } else {
      return logger.error("bridge: " + id + ": Client closed", {
        'code': code,
        'signal': signal
      });
    }
  };

  start_client = function() {
    if (!initial) {
      options = require("./" + server_list).servers[instance];
    }
    if (version_override) {
      options.version = version_override_data;
    }
    client = child_process.fork('client.js', [], {
      'silent': true
    });
    client.on('message', function(msg) {
      if (debug) {
        logger.debug("bridge: " + id + ": client message", msg);
      }
      if (msg.event === 'connected') {
        if (initial) {
          initial = false;
          logger.info("bridge: " + id + ": Connected");
        } else {
          logger.info("bridge: " + id + ": Reconnected");
        }
        status.login_errors = 0;
        status.connected = true;
        return app.set('lolclient', client);
      } else if (msg.event === 'throttled') {
        return logger.error("bridge: " + id + ": THROTTLED");
      } else if (msg.event === 'timeout') {
        return logger.error("bridge: " + id + ": TIMEOUT");
      } else if (msg.event === 'memory') {
        return logger.error("bridge: " + id + ": TOO MUCH MEMORY OR SOMETHING");
      } else if (msg.event === 'new_version') {
        logger.warn("bridge: " + id + ": new client version " + msg.data);
        version_override = true;
        version_override_data = msg.data;
        client.removeListener('exit', client_exited);
        client.kill();
        return client_restart();
      }
    }).on('exit', client_exited);
    return client.send({
      'event': 'connect',
      'options': options
    });
  };

  client_restart = function() {
    client.removeAllListeners();
    start_client();
    return status.reconnects += 1;
  };

  if (mode === 'normal') {
    options = require("./" + server_list).servers[instance];
    id = options.region + ":" + options.username;
    process.title = "bridge.js: " + id;
    app.set('port', options.listen_port);
    app.listen(app.settings.port, 'localhost');
    start_client();
  } else if (mode === 'appfog') {
    options = require("./" + server_list).servers[instance];
    id = options.region + ":" + options.username;
    status.id = id;
    app.set('port', process.env.VCAP_APP_PORT);
    app.listen(app.settings.port);
    start_client();
  }

}).call(this);
