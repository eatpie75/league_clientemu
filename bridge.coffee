child_process	= require('child_process')
express			= require('express')
http			= require('http')
path			= require('path')
routes			= require('./routes')
logger			= require('./logger')
debug			= require('./settings.json').debug

options={}
id=''
client={}
initial=true
status=
	login_errors:0
	total_requests:0
	reconnects:0
	connected:false

if process.env.VCAP_APPLICATION?
	af_app=JSON.parse(process.env.VCAP_APPLICATION)
	instance=af_app.instance_index
	port=process.env.VCAP_APP_PORT
	mode='appfog'
	server_list='appfogsettings.json'
else
	port=process.env.PORT || 8080
	mode='normal'
	server_list='settings.json'
	instance=process.argv[2]

process.on('SIGTERM', ()->
	logger.warn("bridge: #{id}: got SIGTERM")
	process.exit(0)
).on('SIGUSR2', ()->
	logger.warn("bridge: #{id}: get SIGUSR2, restarting client")
	client.removeListener('exit', client_exited)
	client.kill()
	setTimeout(->
		client_restart()
	, 3000
	)
)

server_id_middleware=(req, res, next)->
	req.server_id=id
	next()
lolclient_middleware=(req, res, next)->
	req.lolclient=app.get('lolclient')
	next()
bridge_status_middleware=(req, res, next)->
	req.bridge_status=status
	next()

app=express()
app.configure(->
	app.use(server_id_middleware)
	app.use(express.logger({'format':'tiny', 'immediate':false, 'stream':{'write':(msg, enc)->logger.info("http: #{id}: #{msg.slice(0, -1)}")}}))
	app.use(express.bodyParser())
	app.use(express.methodOverride())
	app.use(express.compress())
	app.use(app.router)
	app.use((err, req, res, next)->res.send(500))
)
app.configure('development', ->
	app.use(express.errorHandler())
)

app.get('/status/', bridge_status_middleware, routes.status)
app.get('/mass_update/', lolclient_middleware, routes.mass_update)
app.get('/get_names/', lolclient_middleware, routes.get_names)
app.get('/search/', lolclient_middleware, routes.search)
app.get('/spectate/', lolclient_middleware, routes.spectate)
app.get('/masterybook/', lolclient_middleware, routes.masterybook)


logger.info("bridge: Preparing to connect")

client_exited=(code, signal)->
	status.connected=false
	if debug then logger.debug("bridge: #{id}: client exit", [code, signal])
	if code in [3, 5]
		logger.error("bridge: #{id}: Client closed", {'code':code, 'signal':signal})
		setTimeout(client_restart, 2000)
	else if code in [1, 4]
		get_time=()=>
			if status.login_errors*500+1000<=6000
				logger.info("bridge: #{id}: restarting client in #{status.login_errors*500+1000}ms")
				status.login_errors*500+1000
			else if 10<status.login_errors<20
				logger.info("bridge: #{id}: restarting client in 10s")
				10000
			else if 20<=status.login_errors<30
				logger.info("bridge: #{id}: restarting client in 1m")
				60000
			else if 30<=status.login_errors<40
				logger.info("bridge: #{id}: restarting client in 5m")
				300000
			else if 40<=status.login_errors
				logger.info("bridge: #{id}: restarting client in 10m")
				600000
		status.login_errors+=1
		setTimeout(client_restart, get_time())
	else
		logger.error("bridge: #{id}: Client closed", {'code':code, 'signal':signal})

start_client=->
	if not initial
		options=require("./#{server_list}").servers[instance]
	client=child_process.fork('client.js', [], {'silent':true})
	client.on('message', (msg)->
		if debug then logger.debug("bridge: #{id}: client message", msg)
		if msg.event=='connected'
			if initial
				initial=false
				logger.info("bridge: #{id}: Connected")
			else
				logger.info("bridge: #{id}: Reconnected")
			status.login_errors=0
			status.connected=true
			app.set('lolclient', client)
		else if msg.event=='throttled'
			logger.error("bridge: #{id}: THROTTLED")
		else if msg.event=='timeout'
			logger.error("bridge: #{id}: TIMEOUT")
	).on('exit', client_exited)
	client.send({'event':'connect', 'options':options})
client_restart=->
	client.removeAllListeners()
	start_client()
	status.reconnects+=1

if mode=='normal'
	options=require("./#{server_list}").servers[instance]
	id="#{options.region}:#{options.username}"
	process.title="bridge.js: #{id}"
	app.set('port', options.listen_port)
	app.listen(app.settings.port, 'localhost')
	start_client()
else if mode=='appfog'
	options=require("./#{server_list}").servers[instance]
	id="#{options.region}:#{options.username}"
	status.id=id
	app.set('port', process.env.VCAP_APP_PORT)
	app.listen(app.settings.port)
	start_client()
