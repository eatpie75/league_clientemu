// Generated by CoffeeScript 1.9.0
(function() {
  var http, https, logger, performQueueRequest, u;

  u = require('underscore');

  http = require('http');

  https = require('https');

  logger = require('winston');

  performQueueRequest = function(host, username, password, cb) {
    var attempts, current, options, queue_node, queue_rate, target, user, _attempt_login, _check_queue, _get_ip, _get_token, _next_check, _ref, _request;
    _ref = [username, password, cb], username = _ref[0], password = _ref[1], cb = _ref[2];
    user = '';
    options = {
      'host': host,
      'port': 443,
      'method': 'POST',
      'rejectUnauthorized': false
    };
    current = 0;
    target = 0;
    queue_node = '';
    queue_rate = 0;
    attempts = 0;
    _next_check = function() {
      var delay, diff, modifier, pad, remaining, _minutes, _seconds;
      pad = '00';
      remaining = Math.round((target - current) / queue_rate);
      _minutes = function(num) {
        return Math.floor(num / 60);
      };
      _seconds = function(num) {
        var tmp;
        tmp = Math.round(num % 60).toString();
        return pad.slice(tmp.length) + tmp;
      };
      diff = target - current;
      if (diff < 50) {
        delay = 3000;
      } else if (diff < 100) {
        delay = 7000;
      } else if (diff < 1000) {
        delay = 10000;
      } else if (diff < 10000) {
        delay = 30000;
      } else {
        delay = 180000;
      }
      modifier = Math.min(1.0 + Math.floor(attempts / 5) / 10.0, 2);
      logger.info("login queue: " + username + " in queue, postition:" + current + "/" + target + ", " + (_minutes(remaining)) + ":" + (_seconds(remaining)) + " remaining, next checkin: " + (_minutes((delay * modifier) / 1000)) + ":" + (_seconds((delay * modifier) / 1000)));
      return setTimeout(_check_queue, delay * modifier);
    };
    _check_queue = function() {
      var args;
      args = {
        'path': "/login-queue/rest/queue/ticker/" + this.queue_name
      };
      return _request(args, null, function(err, res) {
        var key;
        key = u.find(u.keys(res), function(tmp) {
          if (Number(tmp) === queue_node) {
            return true;
          } else {
            return false;
          }
        });
        current = parseInt("0x" + res[key]);
        if (current >= target) {
          return _get_token();
        } else {
          return _next_check();
        }
      });
    };
    _get_token = function() {
      var args;
      args = {
        'path': "/login-queue/rest/queue/authToken/" + user
      };
      logger.info("login queue: " + username + " getting login token");
      return _request(args, null, function(err, res) {
        if (res.token != null) {
          return cb(null, res);
        } else {
          attempts += 1;
          return _next_check();
        }
      });
    };
    _get_ip = function(tcb) {
      var args;
      args = {
        'path': '/services/connection_info',
        'host': 'll.leagueoflegends.com',
        'port': 80
      };
      logger.info("login queue: " + username + " getting ip");
      return _request(args, null, function(err, res) {
        return tcb(res.ip_address);
      });
    };
    _attempt_login = function() {
      var args, data;
      args = {
        'path': '/login-queue/rest/queue/authenticate'
      };
      data = "payload=user%3D" + username + "%2Cpassword%3D" + password;
      return _request(args, data, function(err, res) {
        var queue_name, tmp;
        if (res.status === 'LOGIN' && res.token) {
          logger.info("login queue: " + username + " got token");
          return cb(null, res);
        } else if (res.status === 'LOGIN' && !res.token) {
          logger.error("login queue: " + username + " got login but no token");
          cb(username + " got login but no token");
          return process.exit(1);
        } else if (res.status === 'QUEUE') {
          user = res.user;
          queue_name = res.champ;
          queue_node = res.node;
          queue_rate = res.rate + 0.0;
          tmp = u.find(res.tickers, function(ticker) {
            if (ticker.node === queue_node) {
              return true;
            } else {
              return false;
            }
          });
          target = tmp.id;
          current = tmp.current;
          return _next_check();
        } else if (res.status === 'BUSY') {
          logger.warn("login queue: " + username + " got busy server, retrying in " + res.delay, res);
          return setTimeout(_attempt_login, res.delay);
        } else {
          logger.error("login queue: is confused", res);
          return cb('is confused');
        }
      });
    };
    _request = function(kwargs, payload, tcb) {
      var agent, req, req_options;
      req_options = u.clone(options);
      if (kwargs != null) {
        u.extend(req_options, kwargs);
      }
      if (payload == null) {
        req_options.method = 'GET';
      }
      if (req_options.port === 443) {
        agent = https;
      } else {
        agent = http;
      }
      req = agent.request(req_options, function(res) {
        return res.on('data', function(d) {
          var data;
          if (res.statusCode !== 200) {
            logger.error("login queue: " + username + " got " + res.statusCode);
            attempts += 1;
            data = {};
          } else {
            data = JSON.parse(d.toString('utf-8'));
          }
          return tcb(null, data);
        });
      });
      req.on('error', function(err) {
        logger.error(("login queue: " + username + " request error") + err, err);
        req.abort();
        return process.exit(1);
      }).on('socket', function(socket) {
        socket.setTimeout(20000);
        return socket.on('timeout', function() {
          logger.error("login queue: " + username + " timeout on: " + host);
          req.abort();
          return process.exit(1);
        });
      });
      if (payload != null) {
        return req.end(payload);
      } else {
        return req.end();
      }
    };
    return _attempt_login();
  };

  module.exports = performQueueRequest;

}).call(this);
