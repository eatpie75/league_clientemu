uuid		= require('node-uuid')
models		= require('../lib/models')

module.exports=(req, res)->
	_get=(msg)->
		errors='OB-1':'No game', 'OB-2':'Game not observable', 'OB-3':'Game not started yet'
		# console.log(msg)
		if msg.event=="#{rid}__finished"
			data=status:200, requests:msg.extra.requests
			if msg.data.error?
				# data.body=errors[msg.data.error]
				data.body=msg.data
			else
				if link
					data.body="<a href='lolspectate://ip=#{msg.data.ip}&port=#{msg.data.port}&game_id=#{msg.data.game_id}&region=#{msg.data.region}&key=#{msg.data.key}'>#{name}</a>"
				else
					data.body=msg.data
					res.contentType('json')
			client.removeListener('message', _get)
			res.charset='utf8'
			res.send(data.body)
	client=req.lolclient
	rid=uuid.v4()
	name=req.query.name
	if req.query.link? then link=true else link=false
	if req.query.debug? then debug=true else debug=false
	client.on('message', _get)
	client.send({'event':'get', 'model':'SpectatorInfo', 'query':{'name':name, 'debug':debug}, 'uuid':rid})