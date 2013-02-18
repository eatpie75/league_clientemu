settings= require('./settings.json')
winston	= require('winston')

if not process.env.VCAP_APPLICATION?
	winston.remove(winston.transports.Console)
	winston.add(winston.transports.File, {'filename':settings.log, 'maxsize':104857600, 'maxFiles':3, 'json':false, 'handleExceptions':true})
else
	winston.remove(winston.transports.Console)
	winston.add(winston.transports.Console, {'handleExceptions':true})

module.exports=winston
