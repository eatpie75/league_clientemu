util		= require('util')
uuid		= require('node-uuid')
models		= require('../lib/models')

has_key=(obj, key)->obj.hasOwnProperty(key)


module.exports=(req, res)->
	client=req.lolclient
	rid=[uuid.v4(), uuid.v4(), uuid.v4(), uuid.v4()]
	data=
		status:200
		body:{errors:[], accounts:{}}
		requests:0
	running_queries=0
	queue=[]
	if req.query['accounts']?
		queue=queue.concat(({'account_id':account} for account in req.query['accounts'].split(',')))
	if req.query['names']?
		queue=queue.concat(({'name':name} for name in req.query['names'].split(',')))
	if req.query['games']? then games=1 else games=0
	if req.query['runes']? then runes=true else runes=false
	if req.query['masteries']? then masteries=true else masteries=false
	_get=(msg)->
		if msg.event=="#{rid[0]}__finished"
			summoner=msg.data
			data.requests+=msg.extra.requests
			if not has_key(data.body.accounts, summoner.account_id)
				data.body.accounts[summoner.account_id]={}
			data.body.accounts[summoner.account_id].profile=summoner
			if runes then data.body.accounts[summoner.account_id].runes=msg.extra.runes
			client.send({'event':'get', 'model':'PlayerStats', 'query':{'account_id':summoner.account_id}, 'uuid':rid[1]})
			if games
				running_queries+=1
				client.send({'event':'get', 'model':'RecentGames', 'query':{'account_id':summoner.account_id}, 'uuid':rid[2]})
			if masteries
				running_queries+=1
				client.send({'event':'get', 'model':'MasteryBook', 'query':{'summoner_id':summoner.summoner_id, 'account_id':summoner.account_id}, 'uuid':rid[3]})
		else if msg.event=="#{rid[1]}__finished"
			data.requests+=msg.extra.requests
			data.body.accounts[msg.extra.account_id].stats=msg.data
			running_queries-=1
			if not masteries then _next()
		else if msg.event=="#{rid[2]}__finished"
			data.requests+=msg.extra.requests
			running_queries-=1
			data.body.accounts[msg.extra.account_id].games=msg.data
			if not masteries then _next()
		else if msg.event=="#{rid[3]}__finished"
			data.requests+=msg.extra.requests
			running_queries-=1
			data.body.accounts[msg.extra.account_id].masteries=msg.data
			_next()
		else if msg.event in ['throttled','timeout']
			throttled()
		else
			console.log(msg)
	_next=->
		if running_queries<3 and queue.length>0
			running_queries+=1
			key=queue.shift()
			console.log(key)
			extra={'runes':runes, 'masteries':masteries}
			try
				client.send({'event':'get', 'model':'Summoner', 'query':key, 'uuid':rid[0], 'extra':extra})
			catch error
				console.log(error)
				console.log('oh god')
		else if running_queries==0 and queue.length==0
			client.removeListener('message', _get)
			res.charset='utf8'
			res.contentType('json')
			res.send(JSON.stringify(data.body))
	throttled=->
		client.removeListener('message', _get)
		queue=[]
		res.writeHead(500)
		res.end()
	client.on('message', _get)
	_next()
