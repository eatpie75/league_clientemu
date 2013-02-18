tls			= require('tls')
loginQueue	= require('./login-queue')
lolPackets	= require('./packets')
rtmp		= require('namf/rtmp')
logger		= require('winston')

RTMPClient	= rtmp.RTMPClient
RTMPCommand	= rtmp.RTMPCommand

EventEmitter= require('events').EventEmitter

class LolClient extends EventEmitter
	_rtmpHosts:{
		'na':	'prod.na1.lol.riotgames.com'
		'euw':	'prod.eu.lol.riotgames.com'
		'eune':	'prod.eun1.lol.riotgames.com'
		'br':	'prod.br.lol.riotgames.com'
		'pbe':	'prod.pbe1.lol.riotgames.com'
	}
	
	_loginQueueHosts:{
		'na':	'lq.na1.lol.riotgames.com'
		'euw':	'lq.eu.lol.riotgames.com'
		'eune':	'lq.eun1.lol.riotgames.com'
		'br':	'lq.br.lol.riotgames.com'
		'pbe':	'lq.pbe1.lol.riotgames.com'
	}

	constructor:(@options)->
		if @options.region
			@options.host=@_rtmpHosts[@options.region]
			@options.lqHost=@_loginQueueHosts[@options.region]
		else
			@options.host=@options.host
			@options.lqHost=@option.lqHost
		@options.port=@options.port || 2099

		@options.username=@options.username
		@options.password=@options.password
		@options.version=@options.version
		@options.debug=@options.debug || false

		@keep_alive_counter=0

		logger.info('lol-client: options:', @options) if @options.debug

	connect:(cb)->
		@checkLoginQueue((err, token)=>
			logger.error('lol-client: connection error', err) if err
			# return cb(err) if err
			@sslConnect((err, stream)=>
				# return cb(err) if err
				# logger.info('lol-client: stream connected')
				@stream=stream
				@setupRTMP()
			)
		)

	checkLoginQueue:(cb)->
		logger.info('lol-client: Checking Login Queue') if @options.debug
		loginQueue(@options.lqHost, @options.username, @options.password, (err, response)=>
			if err
				logger.error('lol-client: Login Queue Failed', err)# if @options.debug
				cb(err)
			else
				if !response.token
					cb(new Error('Login Queue Response had no token'))
				else
					logger.info('lol-client: Login Queue Response', response) if @options.debug
					@options.queueToken=response.token
					@options.queue_ip=response.ip_address if response.ip_address?
					cb(null, @options.queueToken)
		)

	sslConnect:(cb)->
		logger.info('lol-client: Connecting to SSL') if @options.debug

		to={}
		stream=tls.connect(@options.port, @options.host, ()=>
			clearTimeout(to)
			cb(null, stream)
		)
		to=setTimeout(
			()->
				logger.error('lol-client: ssl timeout')
				stream.destroySoon()
				process.exit(1)
			, 30000
		)
		stream.on('error', ()=>
			stream.destroySoon()
		)


	setupRTMP:()->
		logger.info('lol-client: Setting up RTMP Client') if @options.debug
		@rtmp=new RTMPClient(@stream)
		logger.info('lol-client: Handshaking RTMP') if @options.debug
		@rtmp.handshake((err)=>
			if err
				@stream.destroy()
			else
				@performNetConnect()
		)

	performNetConnect:()->
		logger.info('lol-client: Performing RTMP NetConnect') if @options.debug
		ConnectPacket=lolPackets.ConnectPacket
		pkt=new ConnectPacket(@options)
		cmd=new RTMPCommand(0x14, 'connect', null, pkt.appObject(), [false, 'nil', '', pkt.commandObject()])
		@rtmp.send(cmd, (err, result)=>
			if err
				logger.error('lol-client: NetConnect failed') if @options.debug
				@stream.destroy()
			else
				logger.error('lol-client: NetConnect success') if @options.debug
				@performLogin(result)
		)

	performLogin:(result)=>
		logger.info('lol-client: Performing RTMP Login...') if @options.debug
		LoginPacket=lolPackets.LoginPacket
		@options.dsid=result.args[0].id

		cmd=new RTMPCommand(0x11, null, null, null, [new LoginPacket(@options).generate(@options.version)])
		@rtmp.send(cmd, (err, result)=>
			if err
				logger.error('lol-client: RTMP Login failed') if @options.debug
				@stream.destroy()
			else
				@performAuth(result)
		)

	performAuth:(result)=>
		logger.info('lol-client: Performing RTMP Auth..') if @options.debug
		AuthPacket = lolPackets.AuthPacket
		
		@options.authToken=result.args[0].body.object.token
		@options.account_id=result.args[0].body.object.accountSummary.object.accountId.value
		cmd = new RTMPCommand(0x11, null, null, null, [new AuthPacket(@options).generate()])
		@rtmp.send(cmd, (err, result)=>
			if err
				logger.info('lol-client: RTMP Auth failed') if @options.debug
			else
				logger.error('lol-client: Connect Process Completed') if @options.debug
				@emit('connection')
				@rtmp.ev.on('throttled', =>@emit('throttled'))
		)
	
	getSummonerByName:(name, cb)=>
		logger.info("Finding player by name: #{name}") if @options.debug
		LookupPacket=lolPackets.LookupPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new LookupPacket(@options).generate(name)])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)

	getSummonerStats:(account_id, cb)=>
		logger.info("Fetching Summoner Stats for #{account_id}") if @options.debug
		PlayerStatsPacket=lolPackets.PlayerStatsPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new PlayerStatsPacket(@options).generate(Number(account_id))])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)

	getMatchHistory:(account_id, cb)=>
		logger.info("Fetching recent games for #{account_id}") if @options.debug
		RecentGamesPacket=lolPackets.RecentGamesPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new RecentGamesPacket(@options).generate(Number(account_id))])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)

	getAggregatedStats:(account_id, cb)=>
		AggregatedStatsPacket=lolPackets.AggregatedStatsPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new AggregatedStatsPacket(@options).generate(Number(account_id))])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)
	
	getTeamsForSummoner:(summoner_id, cb)=>
		GetTeamForSummonerPacket=lolPackets.GetTeamForSummonerPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new GetTeamForSummonerPacket(@options).generate(Number(summoner_id))])
		@rtmp.send(cmd, (err, result)=>
			cb(err) if err
			cb(err, null) unless result?.args?[0]?.body?
			cb(err, result.args[0].body)
		)

	getTeamById:(team_id, cb)=>
		GetTeamByIdPacket=lolPackets.GetTeamByIdPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new GetTeamByIdPacket(@options).generate(team_id)])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body
			return cb(err, result.args[0].body)
		)

	getSummonerData:(account_id, cb)=>
		GetSummonerDataPacket=lolPackets.GetSummonerDataPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new GetSummonerDataPacket(@options).generate(account_id)])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body
			return cb(err, result.args[0].body)
		)

	getSummonerName:(name, cb)=>
		logger.info("Finding name by summonerId: #{name}") if @options.debug
		GetSummonerNamePacket=lolPackets.GetSummonerNamePacket
		cmd=new RTMPCommand(0x11, null, null, null, [new GetSummonerNamePacket(@options).generate(name)])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)

	getSpectatorInfo:(name, cb)=>
		logger.info("Finding spectator info by summonerId: #{name}") if @options.debug
		getSpectatorInfoPacket=lolPackets.GetSpectatorInfoPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new getSpectatorInfoPacket(@options).generate(name)])
		@rtmp.send(cmd, (err, result)=>
			return cb(err.args[0].error) if err?.args?[0]?.error?
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)

	getMasteryBook:(summoner_id, cb)=>
		logger.info("Finding masteries by summonerId: #{summoner_id}") if @options.debug
		getMasteryBookPacket=lolPackets.GetMasteryBookPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new getMasteryBookPacket(@options).generate(summoner_id)])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)

	getAllLeaguesForPlayer:(summoner_id, cb)=>
		logger.info("Finding leagues for summonerId: #{summoner_id}") if @options.debug
		GetAllLeaguesForPlayerPacket=lolPackets.GetAllLeaguesForPlayerPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new GetAllLeaguesForPlayerPacket(@options).generate(summoner_id)])
		@rtmp.send(cmd, (err, result)=>
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)

	keepAlive:(cb)=>
		logger.info("Sending Heartbeat") if @options.debug
		HeartbeatPacket=lolPackets.HeartbeatPacket
		cmd=new RTMPCommand(0x11, null, null, null, [new HeartbeatPacket(@options).generate(@options.account_id, @keep_alive_counter)])
		@rtmp.send(cmd, (err, result)=>
			@keep_alive_counter+=1
			return cb(err) if err
			return cb(err, null) unless result?.args?[0]?.body?
			return cb(err, result.args[0].body)
		)

module.exports = LolClient
