u		= require('underscore')
http	= require('http')
https	= require('https')
logger	= require('winston')

performQueueRequest=(host, username, password, cb)->
	[username, password, cb]=[username, password, cb]
	user=''
	options={
		'host':host
		'port':443
		'method':'POST'
		'rejectUnauthorized':false
	}
	current=0
	target=0
	queue_node=''
	queue_rate=0
	attempts=0
	_next_check=->
		pad='00'
		remaining=Math.round((target-current)/queue_rate)
		_minutes=(num)->
			# tmp=Math.floor(num/60).toString()
			# pad.slice(tmp.length)+tmp
			Math.floor(num/60)
		_seconds=(num)->
			tmp=Math.round(num%60).toString()
			pad.slice(tmp.length)+tmp
		diff=target-current
		if diff<50
			delay=3000
		else if diff<100
			delay=7000
		else if diff<1000
			delay=10000
		else if diff<10000
			delay=30000
		else
			delay=180000
		modifier=Math.min((1.0+Math.floor(attempts/5)/10.0), 2)
		logger.info("login queue: #{username} in queue, postition:#{current}/#{target}, #{_minutes(remaining)}:#{_seconds(remaining)} remaining, next checkin: #{_minutes((delay*modifier)/1000)}:#{_seconds((delay*modifier)/1000)}")
		setTimeout(_check_queue, delay*modifier)
	_check_queue=->
		args={'path':"/login-queue/rest/queue/ticker/#{@queue_name}"}
		# logger.info("login queue: #{username} checking queue")
		_request(args, null, (err, res)->
			key=u.find(u.keys(res), (tmp)->
				if Number(tmp)==queue_node then true else false
			)
			current=parseInt("0x#{res[key]}")
			if current>=target
				_get_token()
			else
				_next_check()
		)
	_get_token=->
		args={'path':"/login-queue/rest/queue/authToken/#{user}"}
		logger.info("login queue: #{username} getting login token")
		_request(args, null, (err, res)->
			if res.token?
				# _get_ip((ip)=>
				# 	res.ip_address=ip
				# 	cb(null, res)
				# )
				# logger.info('', res)
				cb(null, res)
			else
				attempts+=1
				_next_check()
		)
	_get_ip=(tcb)->
		args={'path':'/services/connection_info', 'host':'ll.leagueoflegends.com', 'port':80}
		logger.info("login queue: #{username} getting ip")
		_request(args, null, (err, res)->
			tcb(res.ip_address)
		)
	_attempt_login=->
		args={'path':'/login-queue/rest/queue/authenticate'}
		data="payload=user%3D#{username}%2Cpassword%3D#{password}"
		_request(args, data, (err, res)->
			if res.status=='LOGIN' and res.token
				logger.info("login queue: #{username} got token")
				cb(null, res)
			else if res.status=='LOGIN' and not res.token
				logger.error("login queue: #{username} got login but no token")
				cb("#{username} got login but no token")
				process.exit(1)
			else if res.status=='QUEUE'
				user=res.user
				queue_name=res.champ
				queue_node=res.node
				queue_rate=res.rate+0.0
				tmp=u.find(res.tickers, (ticker)=>
					if ticker.node==queue_node then true else false
				)
				target=tmp.id
				current=tmp.current
				_next_check()
			else if res.status=='BUSY'
				logger.warn("login queue: #{username} got busy server, retrying in #{res.delay}", res)
				setTimeout(_attempt_login, res.delay)
			else
				logger.error("login queue: is confused", res)
				cb('is confused')
		)
	_request=(kwargs, payload, tcb)->
		req_options=u.clone(options)
		if kwargs? then u.extend(req_options, kwargs)
		if !payload? then req_options.method='GET'
		if req_options.port==443 then agent=https else agent=http
		req=agent.request(req_options, (res)->
			res.on('data', (d)->
				if res.statusCode!=200
					logger.error("login queue: #{username} got #{res.statusCode}")
					attempts+=1
					data={}
				else
					data=JSON.parse(d.toString('utf-8'))
				tcb(null, data)
			)
		)
		req.on('error', (err)->
			logger.error("login queue: #{username} request error"+err, err)
			req.abort()
			process.exit(1)
		).on('socket', (socket)->
			socket.setTimeout(20000)
			socket.on('timeout', ()->
				logger.error("login queue: #{username} timeout on: #{host}")
				req.abort()
				process.exit(1)
			)
		)
		if payload? then req.end(payload) else req.end()
	_attempt_login()

module.exports = performQueueRequest
