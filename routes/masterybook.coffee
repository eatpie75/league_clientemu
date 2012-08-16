uuid		= require('node-uuid')
models		= require('../lib/models')

module.exports=(req, res)->
	_get=(msg)->
		if msg.event=="#{rid}__finished"
			data=status:200, body:msg.data, requests:msg.extra.requests
			client.removeListener('message', _get)
			res.charset='utf8'
			res.contentType('json')
			res.send(data.body)
	client=req.lolclient
	rid=uuid.v4()
	summoner_id=req.query.summoner_id
	client.on('message', _get)
	client.send({'event':'get', 'model':'MasteryBook', 'query':{'summoner_id':summoner_id}, 'uuid':rid})