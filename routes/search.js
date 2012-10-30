// Generated by CoffeeScript 1.4.0
(function() {
  var models, uuid;

  uuid = require('node-uuid');

  models = require('../lib/models');

  module.exports = function(req, res) {
    var client, name, rid, _get;
    _get = function(msg) {
      var data;
      if (msg.event === ("" + rid + "__finished")) {
        data = {
          status: 200,
          body: msg.data,
          requests: msg.extra.requests
        };
        client.removeListener('message', _get);
        res.charset = 'utf8';
        res.contentType('json');
        return res.send(data.body);
      }
    };
    client = req.lolclient;
    rid = uuid.v4();
    name = req.query.name;
    client.on('message', _get);
    return client.send({
      'event': 'get',
      'model': 'Search',
      'query': {
        'name': name
      },
      'uuid': rid
    });
  };

}).call(this);
