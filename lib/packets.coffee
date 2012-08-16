uuid = require('node-uuid')

Encoder = require('namf/amf0').Encoder
Decoder = require('namf/amf0').Decoder
ASObject = require('namf/messaging').ASObject

class Packet
	constructor:(@options)->

class ConnectPacket extends Packet
	appObject:()->
		object=
			app:			''
			flashVer:		'WIN 10,1,85,3'
			swfUrl:			'app:/mod_ser.dat'
			tcUrl:			'rtmps://beta.lol.riotgames.com:2099'
			fpad:			false
			capabilities:	239
			audioCodecs:	3191
			videoCodecs:	252
			videoFunction:	1
			pageUrl:		undefined
			objectEncoding:	3
		return object
	
	commandObject:()->
		object=new ASObject()
		object.name='flex.messaging.messages.CommandMessage'
		object.object=
			operation:		5
			correlationId:	''
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		'9DC6600E-8F54-604F-AB39-1515B4CBE8AA'
			destination:	''
			headers:{
				DSMessagingVersion: 1
				DSId: 'my-rtmps'
			}
			body: {}
		return object
		
class LoginPacket extends Packet
	constructor:()->
		super

	generate:(clientVersion)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['operation', 'source', 'timestamp', 'clientId', 'timeToLive', 'messageId', 'destination', 'headers', 'body']
		object.object=
			operation:		'login'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'loginService'
			headers:		@generateHeaders()
			body:			[@generateBody(clientVersion)]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

	generateBody:(clientVersion)->
		body=new ASObject()
		body.name='com.riotgames.platform.login.AuthenticationCredentials'
		body.keys=['oldPassword', 'password', 'authToken', 'locale', 'partnerCredentials', 'ipAddress', 'domain', 'username', 'clientVersion', 'securityAnswer']
		body.object=
			password:			@options.password
			authToken:			@options.queueToken
			locale:				'en_US'
			ipAddress:			if @options.queue_ip? then @options.queue_ip else '203.59.95.218'
			domain:				'lolclient.lol.riotgames.com'
			username:			@options.username
			clientVersion:		clientVersion
			operatingSystem:	'Windows 7'
			securityAnswer:		null
			partnerCredentials:	null
			oldPassword:		null
		body.encoding=0
		return body

class AuthPacket extends Packet
	generate:()->
		object=new ASObject()
		object.name='flex.messaging.messages.CommandMessage'
		object.keys=['operation', 'correlationId', 'timestamp', 'clientId', 'timeToLive', 'messageId', 'destination', 'headers', 'body']
		object.object=
			operation:		8
			correlationId:	''
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'auth'
			headers:		@generateHeaders()
			body:			new Buffer("#{@options.username}:#{@options.authToken}", 'utf8').toString('base64')
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class HeartbeatPacket extends Packet
	generate:(account_id, counter)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['operation', 'source', 'timestamp', 'clientId', 'timeToLive', 'messageId', 'destination', 'headers', 'body']
		object.object=
			operation:		'performLCDSHeartBeat'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'loginService'
			headers:		@generateHeaders()
			body:			[account_id, @options.authToken, counter, new Date().toString()[0..-7]]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers


class LookupPacket extends Packet
	generate:(name)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'getSummonerByName'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'summonerService'
			headers:		@generateHeaders()
			body:			[name]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class GetSummonerDataPacket extends Packet
	generate:(account_id)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'getAllPublicSummonerDataByAccount'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'summonerService'
			headers:		@generateHeaders()
			body:			[account_id]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class AggregatedStatsPacket extends Packet
	generate:(account_id)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.key =['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'getAggregatedStats'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'playerStatsService'
			headers:		@generateHeaders()
			body:			[account_id, 'CLASSIC', 'CURRENT']
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class PlayerStatsPacket extends Packet
	generate:(account_id)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'retrievePlayerStatsByAccountId'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'playerStatsService'
			headers:		@generateHeaders()
			body:			[account_id, 'CURRENT']
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class RecentGamesPacket extends Packet
	generate:(account_id)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'getRecentGames'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'playerStatsService'
			headers:		@generateHeaders()
			body:			[account_id]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class GetTeamForSummonerPacket extends Packet
	generate:(summoner_id)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'findPlayer'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'summonerTeamService'
			headers:		@generateHeaders()
			body:			[summoner_id]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class GetTeamByIdPacket extends Packet
	generate:(team_id)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'findTeamById'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'summonerTeamService'
			headers:		@generateHeaders()
			body:			[@generateBody(team_id)]
		object.encoding=0
		return object

	generateBody:(team_id)->
		body=new ASObject()
		body.name='com.riotgames.team.TeamId'
		body.keys=['dataVersion', 'fullId', 'futureData']
		body.object=
			dataVersion:	null
			fullId:			team_id
			futureData:		null
		body.encoding=0
		return body

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class GetSummonerNamePacket extends Packet
	generate:(name)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'getSummonerNames'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'summonerService'
			headers:		@generateHeaders()
			body:			[name]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class GetSpectatorInfoPacket extends Packet
	generate:(name)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'retrieveInProgressSpectatorGameInfo'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'gameService'
			headers:		@generateHeaders()
			body:			[name]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

class GetMasteryBookPacket extends Packet
	generate:(summoner_id)->
		object=new ASObject()
		object.name='flex.messaging.messages.RemotingMessage'
		object.keys=['source', 'operation', 'timestamp', 'messageId', 'clientId', 'timeToLive', 'body', 'destination', 'headers']
		object.object=
			operation:		'getMasteryBook'
			source:			null
			timestamp:		0
			clientId:		null
			timeToLive:		0
			messageId:		uuid().toUpperCase()
			destination:	'masteryBookService'
			headers:		@generateHeaders()
			body:			[summoner_id]
		object.encoding=0
		return object

	generateHeaders:()->
		headers=new ASObject()
		headers.name=''
		headers.object=
			DSId:				@options.dsid
			DSRequestTimeout:	60
			DSEndpoint:			'my-rtmps'
		headers.encoding=2
		return headers

exports.ConnectPacket			=ConnectPacket
exports.LoginPacket				=LoginPacket
exports.AuthPacket				=AuthPacket
exports.HeartbeatPacket			=HeartbeatPacket
exports.LookupPacket			=LookupPacket
exports.GetSummonerDataPacket	=GetSummonerDataPacket
exports.AggregatedStatsPacket	=AggregatedStatsPacket
exports.PlayerStatsPacket		=PlayerStatsPacket
exports.RecentGamesPacket		=RecentGamesPacket
exports.GetTeamForSummonerPacket=GetTeamForSummonerPacket
exports.GetTeamByIdPacket		=GetTeamByIdPacket
exports.GetSummonerNamePacket	=GetSummonerNamePacket
exports.GetSpectatorInfoPacket	=GetSpectatorInfoPacket
exports.GetMasteryBookPacket	=GetMasteryBookPacket
