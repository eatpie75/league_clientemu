uuid		= require('node-uuid')
models		= require('../lib/models')
logger		= require('winston')
debug		= require('../settings.json').debug

has_key=(obj, key)->obj.hasOwnProperty(key)
index_of_object=(array, key, value)->
	index=0
	for iter in array
		if iter[key]==value
			return index
		index+=1
	return -1
log_error=(errors, error, extra={})->
	index=index_of_object(errors, 'error', error)
	if index==-1
		errors.push({'error':error, 'count':0, 'extra':extra})
	else
		errors[index]['count']+=1
		for p,v in extra
			errors[index]['extra'][p]=v
	return errors

module.exports=(req, res)->
	client=req.lolclient
	rid=[uuid.v4(), uuid.v4(), uuid.v4(), uuid.v4(), uuid.v4()]
	data={
		'status':	200
		'body':		{'accounts':[]}
		'requests':	0
	}
	running_queries=0
	queue=[]
	timers=[]
	errors=[]
	if req.query['accounts']?
		queue=queue.concat(({'account_id':account} for account in req.query['accounts'].split(',')))
	if req.query['names']?
		queue=queue.concat(({'name':name} for name in req.query['names'].split(',')))
	if req.query['games']? then games=1 else games=0
	if req.query['runes']? then runes=true else runes=false
	if req.query['masteries']? then masteries=true else masteries=false
	_get=(msg)->
		if msg.event=="#{rid[0]}__finished"
			if msg.data.error?
				if msg.data.error=='RETRY'
					logger.warn("mass update: #{req.server_id}: Empty Summoner", msg.data.error)
					errors=log_error(errors, msg.data.error)
					if errors[index_of_object(errors, 'error', msg.data.error)].count>10
						logger.error("mass update: #{req.server_id}: Too many errors")
						throttled()
					else
						timers.push(setTimeout(->
							client.send({'event':'get', 'model':'Summoner', 'query':msg.query, 'uuid':rid[0], 'extra':{'runes':runes, 'masteries':masteries}})
						, 2000))
				else if msg.data.error=='BANNED'
					logger.warn("mass update: #{req.server_id}: Banned Summoner", msg.data.error)
					errors=log_error(errors, msg.data.error)
					running_queries-=1
					timers.push(setTimeout(->
						_next()
					, 10))
				return null
			if debug then logger.debug('mass update: Summoner', msg.data)
			summoner=msg.data
			data.requests+=msg.extra.requests
			account_index=index_of_object(data.body.accounts, 'account_id', summoner.account_id)
			if account_index==-1
				data.body.accounts.push({'account_id':summoner.account_id, 'summoner_id':summoner.summoner_id})
				account_index=index_of_object(data.body.accounts, 'account_id', summoner.account_id)
			data.body.accounts[account_index].profile=summoner
			if runes then data.body.accounts[account_index].runes=msg.extra.runes
			# client.send({'event':'get', 'model':'PlayerStats', 'query':{'account_id':summoner.account_id}, 'uuid':rid[1]})
			client.send({'event':'get', 'model':'Leagues', 'query':{'summoner_id':summoner.summoner_id}, 'uuid':rid[4]})
			# running_queries+=1
			if games
				running_queries+=1
				client.send({'event':'get', 'model':'RecentGames', 'query':{'account_id':summoner.account_id}, 'uuid':rid[2]})
			if masteries
				running_queries+=1
				client.send({'event':'get', 'model':'MasteryBook', 'query':{'summoner_id':summoner.summoner_id, 'account_id':summoner.account_id}, 'uuid':rid[3]})
		else if msg.event=="#{rid[1]}__finished"
			if msg.data.error?
				logger.warn("mass update: #{req.server_id}: Empty PlayerStats")
				errors=log_error(errors, msg.data.error)
				if errors[index_of_object(errors, 'error', msg.data.error)].count>10
					throttled()
				else
					timers.push(setTimeout(->
						client.send({'event':'get', 'model':'PlayerStats', 'query':msg.query, 'uuid':rid[1]})
					, 2000))
				return null
			if debug then logger.debug('mass update: PlayerStats', msg.data)
			data.requests+=msg.extra.requests
			account_index=index_of_object(data.body.accounts, 'account_id', msg.extra.account_id)
			data.body.accounts[account_index].stats=msg.data
			running_queries-=1
			_next()
		else if msg.event=="#{rid[2]}__finished"
			if msg.data.error?
				logger.warn("mass update: #{req.server_id}: Empty RecentGames")
				errors=log_error(errors, msg.data.error)
				if errors[index_of_object(errors, 'error', msg.data.error)].count>10
					throttled()
				else
					timers.push(setTimeout(->
						client.send({'event':'get', 'model':'RecentGames', 'query':msg.query, 'uuid':rid[2]})
					, 2000))
				return null
			if debug then logger.debug('mass update: RecentGames', msg.data)
			data.requests+=msg.extra.requests
			account_index=index_of_object(data.body.accounts, 'account_id', msg.extra.account_id)
			data.body.accounts[account_index].games=msg.data
			running_queries-=1
			_next()
		else if msg.event=="#{rid[3]}__finished"
			if msg.data.error?
				logger.warn("mass update: #{req.server_id}: Empty MasteryBook")
				errors=log_error(errors, msg.data.error)
				if errors[index_of_object(errors, 'error', msg.data.error)].count>10
					throttled()
				else
					timers.push(setTimeout(->
						client.send({'event':'get', 'model':'MasteryBook', 'query':msg.query, 'uuid':rid[3]})
					, 2000))
				return null
			if debug then logger.debug('mass update: MasteryBook', msg.data)
			data.requests+=msg.extra.requests
			account_index=index_of_object(data.body.accounts, 'account_id', msg.extra.account_id)
			data.body.accounts[account_index].masteries=msg.data
			running_queries-=1
			_next()
		else if msg.event=="#{rid[4]}__finished"
			if msg.data.error?
				logger.warn("mass update: #{req.server_id}: Empty Leagues")
				errors=log_error(errors, msg.data.error)
				if errors[index_of_object(errors, 'error', msg.data.error)].count>10
					throttled()
				else
					timers.push(setTimeout(->
						client.send({'event':'get', 'model':'Leagues', 'query':msg.query, 'uuid':rid[4]})
					, 2000))
				return null
			if debug then logger.debug('mass update: Leagues', msg.data)
			data.requests+=msg.extra.requests
			account_index=index_of_object(data.body.accounts, 'summoner_id', msg.extra.summoner_id)
			data.body.accounts[account_index].leagues=msg.data
			running_queries-=1
			_next()
		else if msg.event in ['throttled','timeout']
			throttled()
		# else
		# 	logger.error('mass update: unknown event', msg)
	_next=->
		if running_queries<3 and queue.length>0
			running_queries+=1
			key=queue.shift()
			logger.info("mass update: #{req.server_id}: ", key)
			extra={'runes':runes, 'masteries':masteries}
			try
				client.send({'event':'get', 'model':'Summoner', 'query':key, 'uuid':rid[0], 'extra':extra})
			catch error
				logger.error("mass_update: #{req.server_id}:  oh god", error)
		else if running_queries==0 and queue.length==0
			client.removeListener('message', _get)
			res.charset='utf8'
			res.contentType('json')
			res.send(JSON.stringify({'data':data.body, 'server':req.server_id}))
	throttled=->
		for timer in timers
			clearTimeout(timer)
		client.removeListener('message', _get)
		queue=[]
		res.writeHead(500)
		res.end()
	client.on('message', _get)
	_next()
