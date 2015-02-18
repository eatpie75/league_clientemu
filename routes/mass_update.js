// Generated by CoffeeScript 1.9.0
(function() {
  var debug, has_key, index_of_object, log_error, logger, models, uuid;

  uuid = require('node-uuid');

  models = require('../lib/models');

  logger = require('winston');

  debug = require('../settings.json').debug;

  has_key = function(obj, key) {
    return obj.hasOwnProperty(key);
  };

  index_of_object = function(array, key, value) {
    var index, iter, _i, _len;
    index = 0;
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      iter = array[_i];
      if (iter[key] === value) {
        return index;
      }
      index += 1;
    }
    return -1;
  };

  log_error = function(errors, error, extra) {
    var index, p, v, _i, _len;
    if (extra == null) {
      extra = {};
    }
    index = index_of_object(errors, 'error', error);
    if (index === -1) {
      errors.push({
        'error': error,
        'count': 0,
        'extra': extra
      });
    } else {
      errors[index]['count'] += 1;
      for (v = _i = 0, _len = extra.length; _i < _len; v = ++_i) {
        p = extra[v];
        errors[index]['extra'][p] = v;
      }
    }
    return errors;
  };

  module.exports = function(req, res) {
    var account, client, data, errors, games, masteries, name, queue, rid, runes, running_queries, throttled, timers, _get, _next;
    client = req.lolclient;
    rid = [uuid.v4(), uuid.v4(), uuid.v4(), uuid.v4(), uuid.v4()];
    data = {
      'status': 200,
      'body': {
        'accounts': []
      },
      'requests': 0
    };
    running_queries = 0;
    queue = [];
    timers = [];
    errors = [];
    if (req.query['accounts'] != null) {
      queue = queue.concat((function() {
        var _i, _len, _ref, _results;
        _ref = req.query['accounts'].split(',');
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          account = _ref[_i];
          _results.push({
            'account_id': account
          });
        }
        return _results;
      })());
    }
    if (req.query['names'] != null) {
      queue = queue.concat((function() {
        var _i, _len, _ref, _results;
        _ref = req.query['names'].split(',');
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          name = _ref[_i];
          _results.push({
            'name': name
          });
        }
        return _results;
      })());
    }
    if (req.query['games'] != null) {
      games = 1;
    } else {
      games = 0;
    }
    if (req.query['runes'] != null) {
      runes = true;
    } else {
      runes = false;
    }
    if (req.query['masteries'] != null) {
      masteries = true;
    } else {
      masteries = false;
    }
    _get = function(msg) {
      var account_index, summoner, _ref;
      if (msg.event === (rid[0] + "__finished")) {
        if (msg.data.error != null) {
          if (msg.data.error === 'RETRY') {
            logger.warn("mass update: " + req.server_id + ": Empty Summoner", msg.data.error);
            errors = log_error(errors, msg.data.error);
            if (errors[index_of_object(errors, 'error', msg.data.error)].count > 10) {
              logger.error("mass update: " + req.server_id + ": Too many errors");
              throttled();
            } else {
              timers.push(setTimeout(function() {
                return client.send({
                  'event': 'get',
                  'model': 'Summoner',
                  'query': msg.query,
                  'uuid': rid[0],
                  'extra': {
                    'runes': runes,
                    'masteries': masteries
                  }
                });
              }, 2000));
            }
          } else if (msg.data.error === 'BANNED') {
            logger.warn("mass update: " + req.server_id + ": Banned Summoner", msg.data.error);
            errors = log_error(errors, msg.data.error);
            running_queries -= 1;
            timers.push(setTimeout(function() {
              return _next();
            }, 10));
          }
          return null;
        }
        if (debug) {
          logger.debug('mass update: Summoner', msg.data);
        }
        summoner = msg.data;
        data.requests += msg.extra.requests;
        account_index = index_of_object(data.body.accounts, 'account_id', summoner.account_id);
        if (account_index === -1) {
          data.body.accounts.push({
            'account_id': summoner.account_id,
            'summoner_id': summoner.summoner_id
          });
          account_index = index_of_object(data.body.accounts, 'account_id', summoner.account_id);
        }
        data.body.accounts[account_index].profile = summoner;
        if (runes) {
          data.body.accounts[account_index].runes = msg.extra.runes;
        }
        client.send({
          'event': 'get',
          'model': 'Leagues',
          'query': {
            'summoner_id': summoner.summoner_id
          },
          'uuid': rid[4]
        });
        if (games) {
          running_queries += 1;
          client.send({
            'event': 'get',
            'model': 'RecentGames',
            'query': {
              'account_id': summoner.account_id
            },
            'uuid': rid[2]
          });
        }
        if (masteries) {
          running_queries += 1;
          return client.send({
            'event': 'get',
            'model': 'MasteryBook',
            'query': {
              'summoner_id': summoner.summoner_id,
              'account_id': summoner.account_id
            },
            'uuid': rid[3]
          });
        }
      } else if (msg.event === (rid[1] + "__finished")) {
        if (msg.data.error != null) {
          logger.warn("mass update: " + req.server_id + ": Empty PlayerStats");
          errors = log_error(errors, msg.data.error);
          if (errors[index_of_object(errors, 'error', msg.data.error)].count > 10) {
            throttled();
          } else {
            timers.push(setTimeout(function() {
              return client.send({
                'event': 'get',
                'model': 'PlayerStats',
                'query': msg.query,
                'uuid': rid[1]
              });
            }, 2000));
          }
          return null;
        }
        if (debug) {
          logger.debug('mass update: PlayerStats', msg.data);
        }
        data.requests += msg.extra.requests;
        account_index = index_of_object(data.body.accounts, 'account_id', msg.extra.account_id);
        data.body.accounts[account_index].stats = msg.data;
        running_queries -= 1;
        return _next();
      } else if (msg.event === (rid[2] + "__finished")) {
        if (msg.data.error != null) {
          logger.warn("mass update: " + req.server_id + ": Empty RecentGames");
          errors = log_error(errors, msg.data.error);
          if (errors[index_of_object(errors, 'error', msg.data.error)].count > 10) {
            throttled();
          } else {
            timers.push(setTimeout(function() {
              return client.send({
                'event': 'get',
                'model': 'RecentGames',
                'query': msg.query,
                'uuid': rid[2]
              });
            }, 2000));
          }
          return null;
        }
        if (debug) {
          logger.debug('mass update: RecentGames', msg.data);
        }
        data.requests += msg.extra.requests;
        account_index = index_of_object(data.body.accounts, 'account_id', msg.extra.account_id);
        data.body.accounts[account_index].games = msg.data;
        running_queries -= 1;
        return _next();
      } else if (msg.event === (rid[3] + "__finished")) {
        if (msg.data.error != null) {
          logger.warn("mass update: " + req.server_id + ": Empty MasteryBook");
          errors = log_error(errors, msg.data.error);
          if (errors[index_of_object(errors, 'error', msg.data.error)].count > 10) {
            throttled();
          } else {
            timers.push(setTimeout(function() {
              return client.send({
                'event': 'get',
                'model': 'MasteryBook',
                'query': msg.query,
                'uuid': rid[3]
              });
            }, 2000));
          }
          return null;
        }
        if (debug) {
          logger.debug('mass update: MasteryBook', msg.data);
        }
        data.requests += msg.extra.requests;
        account_index = index_of_object(data.body.accounts, 'account_id', msg.extra.account_id);
        data.body.accounts[account_index].masteries = msg.data;
        running_queries -= 1;
        return _next();
      } else if (msg.event === (rid[4] + "__finished")) {
        if (msg.data.error != null) {
          logger.warn("mass update: " + req.server_id + ": Empty Leagues");
          errors = log_error(errors, msg.data.error);
          if (errors[index_of_object(errors, 'error', msg.data.error)].count > 10) {
            throttled();
          } else {
            timers.push(setTimeout(function() {
              return client.send({
                'event': 'get',
                'model': 'Leagues',
                'query': msg.query,
                'uuid': rid[4]
              });
            }, 2000));
          }
          return null;
        }
        if (debug) {
          logger.debug('mass update: Leagues', msg.data);
        }
        data.requests += msg.extra.requests;
        account_index = index_of_object(data.body.accounts, 'summoner_id', msg.extra.summoner_id);
        data.body.accounts[account_index].leagues = msg.data;
        running_queries -= 1;
        return _next();
      } else if ((_ref = msg.event) === 'throttled' || _ref === 'timeout') {
        return throttled();
      }
    };
    _next = function() {
      var error, extra, key;
      if (running_queries < 3 && queue.length > 0) {
        running_queries += 1;
        key = queue.shift();
        logger.info("mass update: " + req.server_id + ": ", key);
        extra = {
          'runes': runes,
          'masteries': masteries
        };
        try {
          return client.send({
            'event': 'get',
            'model': 'Summoner',
            'query': key,
            'uuid': rid[0],
            'extra': extra
          });
        } catch (_error) {
          error = _error;
          return logger.error("mass_update: " + req.server_id + ":  oh god", error);
        }
      } else if (running_queries === 0 && queue.length === 0) {
        client.removeListener('message', _get);
        res.charset = 'utf8';
        res.contentType('json');
        return res.send(JSON.stringify({
          'data': data.body,
          'server': req.server_id
        }));
      }
    };
    throttled = function() {
      var timer, _i, _len;
      for (_i = 0, _len = timers.length; _i < _len; _i++) {
        timer = timers[_i];
        clearTimeout(timer);
      }
      client.removeListener('message', _get);
      queue = [];
      res.writeHead(500);
      return res.end();
    };
    client.on('message', _get);
    return _next();
  };

}).call(this);
