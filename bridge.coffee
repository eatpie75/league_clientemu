child_process	= require('child_process')
colors			= require('colors')
util			= require('util')

express			= require('express')
routes			= require('./routes')
http			= require('http')
path			= require('path')

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
	server_list='appfogservers.json'
else
	port=process.env.PORT || 8080
	mode='normal'
	server_list='servers.json'


_log=(text)->
	if mode=='normal'
		process.send({event:'log', server:"#{id}", text:text})
	else
		console.log(text)


lolclient_middleware=(req, res, next)->
	req.lolclient=app.get('lolclient')
	next()
bridge_status_middleware=(req, res, next)->
	req.bridge_status=status
	next()

app=express()
app.configure(->
	app.use(express.logger('dev'))
	app.use(express.bodyParser())
	app.use(express.methodOverride())
	app.use(express.compress())
	app.use(app.router)
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


_log("Preparing to connect".grey)


start_client=->
	if not initial
		if mode=='normal'
			options=require("./#{server_list}")[id]
		else if mode=='appfog'
			options=require("./#{server_list}")[instance]
	client=child_process.fork('client.js')
	client.on('message', (msg)->
		#console.log(msg)
		if msg.event=='connected' and initial
			initial=false
			_log("Connected".green)
			status.login_errors=0
			status.connected=true
			app.set('lolclient', client)
			if mode=='normal'
				app.listen(app.settings.port, 'localhost')
			else if mode=='appfog'
				app.listen(app.settings.port)
		else if msg.event=='connected' and not initial
			_log('Reconnected'.green)
			status.login_errors=0
			status.connected=true
			app.set('lolclient', client)
		else if msg.event=='throttled'
			_log("THROTTLED".red)
		else if msg.event=='timeout'
			_log("TIMEOUT".red)
		else if msg.event=='log'
			_log(msg.text)
	).on('exit', (code, signal)->
		status.connected=false
		if code in [3, 5]
			console.log(code, signal)
			setTimeout(client_restart, 2000)
		else if code in [1,4]
			get_time=()=>
				if status.login_errors*500+1000<=6000
					_log("restarting client in #{status.login_errors*500+1000}ms")
					status.login_errors*500+1000
				else if 10<status.login_errors<20
					_log('restarting client in 10s')
					10000
				else if 20<=status.login_errors<30
					_log('restarting client in 1m')
					60000
				else if 30<=status.login_errors<40
					_log('restarting client in 5m')
					300000
				else if 40<=status.login_errors
					_log('restarting client in 10m')
					600000
			status.login_errors+=1
			setTimeout(client_restart, get_time())
		else
			console.log(code, signal)
	)
	client.send({event:'connect', options:options})
client_restart=->
	client.removeAllListeners()
	client=null
	start_client()
	status.reconnects+=1

if mode=='normal'
	process.on('message', (msg)->
		if msg.event=='connect'
			id=msg.id
			options=msg.options
			app.set('port', options.listen_port)
			start_client()
		else if msg.event=='status'
			process.send({event:'status', data:{connected:status.connected, total_requests:status.total_requests, reconnects:status.reconnects}, server:"#{id}"})
		else
			msg=null
	)
else if mode=='appfog'
	options=require("./#{server_list}")[instance]
	id="#{options.region}:#{options.username}"
	status.id=id
	app.set('port', process.env.VCAP_APP_PORT)
	start_client()
