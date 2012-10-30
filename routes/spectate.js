// Generated by CoffeeScript 1.4.0
(function() {
  var models, uuid;

  uuid = require('node-uuid');

  models = require('../lib/models');

  module.exports = function(req, res) {
    var client, debug, full, link, name, rid, _get;
    _get = function(msg) {
      var data, errors;
      errors = {
        'OB-1': 'No game',
        'OB-2': 'Game not observable',
        'OB-3': 'Game not started yet'
      };
      if (msg.event === ("" + rid + "__finished")) {
        data = {
          status: 200,
          requests: msg.extra.requests
        };
        if (msg.data.error != null) {
          data.body = msg.data;
        } else {
          if (link) {
            data.body = "<a href='lolspectate://ip=" + msg.data.ip + "&port=" + msg.data.port + "&game_id=" + msg.data.game_id + "&region=" + msg.data.region + "&key=" + msg.data.key + "'>" + name + "</a>";
          } else {
            data.body = msg.data;
            res.contentType('json');
          }
        }
        client.removeListener('message', _get);
        res.charset = 'utf8';
        return res.send(data.body);
      }
    };
    client = req.lolclient;
    rid = uuid.v4();
    name = req.query.name;
    if (req.query.link != null) {
      link = true;
    } else {
      link = false;
    }
    if (req.query.debug != null) {
      debug = true;
    } else {
      debug = false;
    }
    if (req.query.full != null) {
      full = true;
    } else {
      full = false;
    }
    client.on('message', _get);
    return client.send({
      'event': 'get',
      'model': 'SpectatorInfo',
      'query': {
        'name': name,
        'debug': debug,
        'full': full
      },
      'uuid': rid
    });
  };

}).call(this);
