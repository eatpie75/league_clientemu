lol_client		= require('./lib/lol-client')
models			= require('./lib/models')
logger			= require('./logger')

options={}
client={}
keepalive={}
id=''

_keepalive=->
	timer=setTimeout(->
		client.emit('timeout')
		logger.error("client: #{id}: keepalive timeout")
	, 10000
	)
	client.keepAlive((err, result)->
		clearTimeout(timer)
		logger.info("client: #{id}: Heartbeat") if Math.random()>=0.75
	)

_check_parent=->
	try
		process.send({'event':'check'})
	catch e
		logger.warn("client: #{id}: parent has died, closing")
		process.exit(5)
check_parent=setInterval(_check_parent, 2000)

process.on('SIGTERM', ()->
	logger.warn("client: #{id}: got SIGTERM")
	process.exit(0)
).on('message', (msg)->
	if msg.event=='connect'
		options={
			region:		msg.options.region
			username:	msg.options.username
			password:	msg.options.password
			version: 	msg.options.version
		}
		id="#{options.region}:#{options.username}"

		client=new lol_client(options)
		client.once('connection', ->
			process.send({'event':'connected'})
			keepalive=setInterval(->
				_keepalive()
			, 120000)
		).once('throttled', ->
			process.send({'event':'throttled'})
			process.exit(3)
		).once('timeout', ->
			process.send({'event':'timeout'})
			process.exit(5)
		)
		client.connect()
		process.title="client.js: #{id}"
	else if msg.event=='get'
		_get=(data, extra={})->
			extra.region=options.region
			process.send({'event':"#{msg.uuid}__finished", 'data':data, 'extra':extra, 'query':query})
		query=msg.query
		query_options={'client':client}
		if msg.extra? then query_options['extra']=msg.extra
		model=new models[msg.model](_get, query_options)
		model.get(query)
)
