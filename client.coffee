colors			= require('colors')
lol_client		= require('./lib/lol-client')
models			= require('./lib/models')

_log=(text)->
		process.send({event:'log', text:text})
_keepalive=->
	timer=setTimeout(->
		client.emit('timeout')
		console.log('wtf keepalive timeout')
	, 10000
	)
	client.keepAlive((err, result)->
		clearTimeout(timer)
		_log("Heartbeat".magenta) if Math.random()>=0.75
	)

options={}
client={}
keepalive={}

process.on('message', (msg)->
	#console.log(msg)
	if msg.event=='connect'
		options=
			region:		msg.options.region		||'na'				# Lol Client region, one of 'na', 'euw' or 'eune'
			username:	msg.options.username	||'dotaesnumerouno'	# must be lowercase!
			password:	msg.options.password	||'penis2'			# guess
			version: 	msg.options.version		||'1.60.12_05_22_19_12'				# Lol Client version - must be "current" or it wont work. This is correct as at 21/03/2012
		client=new lol_client(options)
		client.on('connection', ->
			process.send({event:'connected'})
			keepalive=setInterval(->
				_keepalive()
			, 120000)
		).on('throttled', ->
			process.send({event:'throttled'})
			process.exit(3)
		).on('timeout', ->
			process.send({event:'timeout'})
			process.exit(5)
		)
		client.connect()
	else if msg.event=='get'
		model={}
		_get=(data, extra={})->
			extra.region=options.region
			process.send({event:"#{msg.uuid}__finished", 'data':data, 'extra':extra})
			model=null
		query=msg.query
		query_options={'client':client}
		if msg.extra? then query_options['extra']=msg.extra
		model=new models[msg.model](_get, query_options)
		model.get(query)
)
