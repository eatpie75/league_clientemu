child_process	= require('child_process')
colors			= require('colors')
express			= require('express')
http			= require('http')
path			= require('path')
routes			= require('./routes')

clients=[]

_log=(msg)->
	blank='                                                 '
	d=new Date()
	time=" #{d.getFullYear()}/#{d.getMonth()+1}/#{d.getDate()} #{d.getHours()}:#{if d.getMinutes()< 10 then '0'+d.getMinutes() else d.getMinutes()}:#{if d.getSeconds()< 10 then '0'+d.getSeconds() else d.getSeconds()}".white
	info=(msg.server+time+blank).slice(0,49)
	console.log(info+" | "+msg.text)


lolclient_middleware=(req, res, next)->
	req.lolclient=app.settings.lolclient
	next()

lolclient_status_middleware=(req, res, next)->
	data=[]
	_add_data=(msg)->
		if msg.event=='status'
			data.push({'server':msg.server, 'data':msg.data})
		if data.length==clients.length
			req.lolclient_status=data
			next()
		@removeListener('message', _add_data)
	for client in clients
		client.on('message', _add_data)
		client.send({event:'status'})

bind_events=(server)->
	server.on('exit', (code, signal)->
		console.log(code, signal)
	).on('message', (msg)->
		if msg.event=='log'
			_log(msg)
	)

servers=require('./servers.json')

for server, options of servers
	tmp=child_process.fork('bridge.js')
	tmp.send({'event':'connect', 'options':options, 'id':server})
	bind_events(tmp)
	clients.push(tmp)

app=express()
app.configure(->
	app.set('port', process.env.PORT || 8080)
	app.set('lolclients', clients)
	app.use(express.logger('dev'))
	app.use(express.bodyParser())
	app.use(express.methodOverride())
	app.use(express.compress())
	app.use(app.router)
)
app.configure('development', ->
	app.use(express.errorHandler())
)

app.get('/status/', lolclient_status_middleware, routes.index)

app.listen(app.settings.port, 'localhost')
