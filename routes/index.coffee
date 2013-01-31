exports.mass_update=require('./mass_update')
exports.get_names=require('./get_names')
exports.search=require('./search')
exports.spectate=require('./spectate')
exports.masterybook=require('./masterybook')

exports.index=(req, res)->
	res.charset='utf8'
	res.contentType('json')
	res.send(JSON.stringify(req.lolclient_status))

exports.status=(req, res)->
	status={
		'data':req.bridge_status,
		'server':req.server_id
	}
	res.charset='utf8'
	res.contentType('json')
	res.send(JSON.stringify(status))
