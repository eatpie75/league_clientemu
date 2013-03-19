// Generated by CoffeeScript 1.6.1
(function() {
  var models, uuid;

  uuid = require('node-uuid');

  models = require('../lib/models');

  module.exports = function(req, res) {
    var client, rid, summoner_id, _get;
    _get = function(msg) {
      var data;
      if (msg.event === ("" + rid + "__finished")) {
        data = {
          'status': 200,
          'body': {
            'data': msg.data,
            'server': req.server_id
          },
          'requests': msg.extra.requests
        };
        client.removeListener('message', _get);
        res.charset = 'utf8';
        res.contentType('json');
        return res.send(data.body);
      }
    };
    client = req.lolclient;
    rid = uuid.v4();
    summoner_id = req.query.summoner_id;
    client.on('message', _get);
    return client.send({
      'event': 'get',
      'model': 'MasteryBook',
      'query': {
        'summoner_id': summoner_id
      },
      'uuid': rid
    });
  };

}).call(this);
