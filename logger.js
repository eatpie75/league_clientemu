// Generated by CoffeeScript 1.4.0
(function() {
  var settings, winston;

  settings = require('./settings.json');

  winston = require('winston');

  if (!(process.env.VCAP_APPLICATION != null)) {
    winston.remove(winston.transports.Console);
    winston.add(winston.transports.File, {
      'filename': settings.log,
      'maxsize': 104857600,
      'maxFiles': 3,
      'json': false,
      'handleExceptions': true
    });
  } else {
    winston.remove(winston.transports.Console);
    winston.add(winston.transports.Console, {
      'handleExceptions': true
    });
  }

  module.exports = winston;

}).call(this);
