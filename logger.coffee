settings	= require('./settings.json')
winston		= require('winston')

if not process.env.VCAP_APPLICATION?
	winston.remove(winston.transports.Console) if not settings.debug
	winston.add(winston.transports.File, {'filename':settings.log, 'maxsize':2000000, 'maxFiles':1, 'json':false, 'handleExceptions':true})
else
	winston.remove(winston.transports.Console)
	winston.add(winston.transports.Console, {'handleExceptions':true, 'timestamp':true})

module.exports=winston
