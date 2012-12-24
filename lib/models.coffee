json	= JSON.stringify
util	= require('util')

has_key=(obj, key)->obj.hasOwnProperty(key)
get_object_index=(array, key, value)->
	i=0
	for row in array
		if has_key(row, key) and row[key]==value
			return i
			break
		else
			i+=1
	return -1

class PlayerNames
	constructor:(@cb, options)->
		if options?
			if options.hasOwnProperty('client')
				@client=options.client
			if options.hasOwnProperty('summoners') then @summoners=summoners
		@data=[]
	parse:=>
		#
	get:(args)=>
		#console.log(args)
		@summoners=args.summoners
		@client.getSummonerName(@summoners, (err, result)=>
			if err?
				data=err
			else
				data=result.data
			@cb(data, {requests:1})
		)

class PlayerStats
	constructor:(@cb, options)->
		if options?
			if options.hasOwnProperty('client') then @client=options.client
			if options.hasOwnProperty('stats')
				@org=options.stats
				@account_id=@org.userId.value
		@data=[]
	parse:=>
		@data=[]
		for game_type in @org.playerStatSummaries.object.playerStatSummarySet.data
			stats=game_type.object
			current={
				'game_type'			:stats.playerStatSummaryTypeString
				'rating'			:stats.rating
				'rating_max'		:stats.maxRating
				'wins'				:stats.wins
				'losses'			:stats.losses
				'leaves'			:stats.leaves
				'aggregated_stats'	:{}
			}
			for stat in stats.aggregatedStats.object.stats.data
				current['aggregated_stats'][stat.object.statType.toLowerCase()]=stat.object.value.value
			@data.push(current)
		return @data
	get:(args)=>
		account_id=args.account_id
		@client.getSummonerStats(account_id, (err, result)=>
			if err?
				data=err
			else if not result?
				@data={'error':'RETRY'}
			else
				@org=result.object
				@account_id=@org.userId.value
				@parse()
			@cb(@data, {account_id:@account_id, requests:1})
		)
	toJSON:=>
		return json(@data)

class RecentGames
	constructor:(@cb, options)->
		#_log('Parsing games'.yellow)
		if options.hasOwnProperty('client') then @client=options.client
		if options.hasOwnProperty('games')
			@org=games
			@account_id=@org.userId.value
		@data=[]
	parse:=>
		@data=[]
		for ogame in @org.gameStatistics.data
			game=ogame.object
			current={
				#'account_id'		:game.userId.value
				'id'				:game.gameId.value
				'game_map'			:game.gameMapId
				'game_mode'			:game.gameMode
				'game_type'			:game.gameType
				'team'				:if game.teamId.value==100 then 'blue' else 'purple'
				'afk'				:game.afk
				'leaver'			:game.leaver
				'invalid'			:game.invalid
				'ip_earned'			:game.ipEarned.value
				'xp_earned'			:game.experienceEarned.value
				'boost_ip'			:game.boostIpEarned.value
				'boost_xp'			:game.boostXpEarned.value
				'champion'			:game.championId.value
				'date'				:game.createDate
				'players'			:(player.object.summonerId.value for player in game.fellowPlayers.data)
				'summoner_level'	:game.level.value
				'premade_size'		:game.premadeSize
				'premade_team'		:game.premadeTeam
				'skin_index'		:game.skinIndex
				'skin_name'			:game.skinName
				'summoner_spell_one':game.spell1.value
				'summoner_spell_two':game.spell2.value
				'queue_length'		:game.timeInQueue
				'queue_type'		:game.queueType
				'ping'				:game.userServerPing
				'stats'				:{}
			}
			#current.players.push(game.userId.value)
			for stat in game.statistics.data
				current['stats'][stat.object.statType.toLowerCase()]=stat.object.value.value
			for key in [
				'num_deaths', 'champions_killed', 'assists', 'largest_critical_strike', 'largest_killing_spree', 'largest_multi_kill',
				'item0', 'item1', 'item2', 'item3', 'item4', 'item5',
				'minions_killed', 'neutral_minions_killed', 'gold_earned',
				'physical_damage_dealt_player', 'magic_damage_dealt_player', 'physical_damage_dealt_to_champions', 'magic_damage_dealt_to_champions'
				'total_damage_dealt', 'total_damage_dealt_to_champions'
				'physical_damage_taken', 'magic_damage_taken', 'total_damage_taken'
				'total_heal', 'total_time_spent_dead',
				'turrets_killed', 'inhibitors_destroyed',
				'lose', 'win',
				'sight_wards_bought_in_game', 'vision_wards_bought_in_game',
				'node_neutralize', 'node_neutralize_assist', 'node_capture', 'node_capture_assist',
				'victory_point_total', 'team_objective', 'objective_player_score', 'combat_player_score', 'total_player_score', 'total_score_rank',
			]
				if not has_key(current.stats, key)
					current.stats[key]=0
			@data.push(current)
			@data.sort((a,b)->if a.id>b.id then -1 else if a.id<b.id then 1 else  0)
		return @data
	get:(args)=>
		account_id=args.account_id
		@client.getMatchHistory(account_id, (err, result)=>
			if err?
				console.log('Error'.red+err)
				data=err
			else if not result?
				@data={'error':'RETRY'}
			else
				@org=result.object
				@account_id=@org.userId.value
				@parse()
			@cb(@data, {account_id:@account_id, requests:1})
		)
	toJSON:=>
		return json(@data)

class Summoner
	constructor:(@cb, options)->
		if options?
			if options.hasOwnProperty('client') then @client=options.client
			if options.hasOwnProperty('summoner')
				@summoner=options.summoner
				@account_id=@summoner.acctId.value
			if options.extra?
				if options.extra.runes? then @runes=options.extra.runes
				if options.extra.masteries? then @masteries=options.extra.masteries
		@data={}
		@requests=0
	parse:=>
		@data={}
		if not @summoner?
			@data={'error':'RETRY'}
			return @data
		current={
			'account_id'		:@summoner.acctId.value
			'summoner_id'		:@summoner.sumId.value
			'internal_name'		:@summoner.internalName
			'name'				:@summoner.name
			'level'				:@org.object.summonerLevelAndPoints.object.summonerLevel.value
			'profile_icon'		:@summoner.profileIconId
			'season_one_tier'	:@summoner.seasonOneTier
			'season_two_tier'	:@summoner.seasonTwoTier
		}
		@data=current
		return @data
	get:(args)=>
		found_account_id=()=>
			@client.getSummonerData(@account_id, (err, result)=>
				if err?
					@data=err
				else
					@org=result
					try
						@summoner=result.object.summoner.object
						@account_id=@summoner.acctId.value
					catch e
						console.log e
						console.log util.inspect(result, false, 10, true)
					@parse()
				extra={requests:@requests+1}
				if @runes and @org?.object? then extra['runes']=new RunePage({'book':@org.object.spellBook.object}).parse()
				@cb(@data, extra)
			)
		if has_key(args, 'account_id')
			@account_id=args.account_id
			found_account_id()
		else if has_key(args, 'name')
			@client.getSummonerByName(args.name, (err, result)=>
				@requests+=1
				if err?
					@data=err
					@cb(@data, {requests:@requests})
				else
					@account_id=result.object.acctId.value
					found_account_id()
			)
	toJSON:=>
		return json(@data)

class Search
	constructor:(@cb, options)->
		if options?
			if has_key(options, 'client') then @client=options.client
			if has_key(options, 'search')
				@search=options.search
				@account_id=@search.account_id
		@data={}
	parse:=>
		console.log(@search)
		@data={}
		current={
			'account_id'		:@search.acctId.value
			'summoner_id'		:@search.summonerId.value
			'internal_name'		:@search.internalName
			'name'				:@search.name
			'level'				:@search.summonerLevel.value
			'profile_icon'		:@search.profileIconId
			'region'			:@client.options.region
		}
		@data=current
		return @data
	get:(args)=>
		name=args.name
		@client.getSummonerByName(name, (err, result)=>
			if err?
				@data=err
			else if err==null and result==null
				@data={}
			else
				# console.log(err, result)
				@account_id=result.object.acctId.value
				@search=result.object
				@parse()
			@cb(@data, {requests:1})
		)
	toJSON:=>
		return json(@data)


class RunePage
	constructor:(options)->
		if options?
			if has_key(options, 'client') then @client=options.client
			if has_key(options, 'book') then @book=options.book
		@data=[]
	parse:=>
		@data=[]
		for page in @book.bookPages.data
			page=page.object
			if page.name.match(/@@!PaG3!@@\d+/) then continue
			current={
				'id'		:page.pageId.value
				'name'		:page.name
				'created'	:page.createDate
				'active'	:page.current
				'slots'		:[]
			}
			for rune in page.slotEntries.data
				rune=rune.object
				tmp={
					'slot'	:rune.runeSlotId
					'id'	:rune.runeId
				}
				current.slots.push(tmp)
			current.slots.sort(@_rsort)
			@data.push(current)
		@data.sort(@_msort)
		return @data
	# get:(args)=>
	# 	@account_id=args.account_id
	# 	@client.getMasteryBook(@account_id, (err, result)=>
	# 		if err?
	# 			@data=err
	# 		else
	# 			@book=result.object.bookPages
	# 			@parse()
	# 		@emit('finished', @data, {requests:1})
	# 	)
	_msort:(a,b)=>if a.id<b.id then -1 else if a.id==b.id then 0 else 1
	_rsort:(a,b)=>if a.slot<b.slot then -1 else if a.slot==b.slot then 0 else 1
	toJSON:=>
		return json(@data)


class MasteryBook
	constructor:(@cb, options)->
		if options?
			if has_key(options, 'client') then @client=options.client
			if has_key(options, 'book') then @book=options.book
	parse:=>
		@data={}
		current=[]
		for page in @book.data
			page=page.object
			if page.name.match(/@@!PaG3!@@\d+/) then continue
			id=page.pageId.value
			tmp={
				'id':		id
				'name':		page.name
				'current':	page.current
				'talents':	[]
			}
			for talent in page.talentEntries.data
				talent=talent.object
				tmp.talents.push({
					'id':	talent.talentId
					'rank':	talent.rank
				})
			tmp.talents.sort(@_msort)
			current.push(tmp)
		current.sort(@_msort)
		@data=current
		return @data
	get:(args)=>
		@summoner_id=args.summoner_id
		@account_id=args.account_id
		@client.getMasteryBook(@summoner_id, (err, result)=>
			if err?
				@data=err
			else
				@book=result.object.bookPages
				@parse()
			@cb(@data, {'account_id':@account_id, requests:1})
		)
	_msort:(a,b)=>if a.id<b.id then -1 else if a.id==b.id then 0 else 1
	toJSON:=>
		return json(@data)


class SpectatorInfo
	constructor:(@cb, options)->
		if options?
			if has_key(options, 'client') then @client=options.client
			if has_key(options, 'info')
				@info=options.info
		@data={}
	parse:=>
		@data={}
		regions={'na':'NA1', 'euw':'EUW1', 'eune':'EUN1'}
		current={
			'key'		:@info.playerCredentials.object.observerEncryptionKey
			'ip'		:@info.playerCredentials.object.observerServerIp
			'port'		:@info.playerCredentials.object.observerServerPort
			'game_id'	:@info.playerCredentials.object.gameId.value
			'region'	:regions[@client.options.region]
			'name'		:@info.game.object.name
		}
		if @full
			current.info={
				'id'		:@info.game.object.id.value
				'game_map'	:@info.game.object.mapId
				'game_mode'	:@info.game.object.gameMode
				'game_type'	:@info.game.object.gameType
				'queue_type':@info.game.object.queueTypeName
				'bans'		:if @info.game.object.bannedChampions.data.length>0 then ({'champion':ban.object.championId, 'turn':ban.object.pickTurn, 'team':if ban.object.teamId==100 then 'blue' else 'purple'} for ban in @info.game.object.bannedChampions.data) else []
				'players'	:[]
			}
			add_players=(data, team)->
				for player in data
					current.info.players.push({
						'account_id'	:player.object.accountId.value
						'summoner_id'	:player.object.summonerId.value
						'internal_name'	:player.object.summonerInternalName
						'name'			:player.object.summonerName
						'turn'			:player.object.pickTurn
						'team'			:team
					})
			add_players(@info.game.object.teamOne.data, 'blue')
			add_players(@info.game.object.teamTwo.data, 'purple')
			for champion in @info.game.object.playerChampionSelections.data
				index=get_object_index(current.info.players, 'internal_name', champion.object.summonerInternalName)
				current.info.players[index]['champion']=champion.object.championId
				current.info.players[index]['summoner_spell_one']=champion.object.spell1Id.value
				current.info.players[index]['summoner_spell_two']=champion.object.spell2Id.value
		@data=current
		return @data
	get:(args)=>
		name=args.name
		@client.getSpectatorInfo(name, (err, result)=>
			if has_key(args, 'full') then @full=args.full
			if err?
				@data={'error':err}
			else
				@info=result.object
				@parse()
				if args.debug
					@data.debug={'err':err, 'res':result.object}
			@cb(@data, {requests:1})
		)
	toJSON:=>
		return json(@data)

exports.PlayerNames		=PlayerNames
exports.PlayerStats		=PlayerStats
exports.RecentGames		=RecentGames
exports.Summoner		=Summoner
exports.RunePage		=RunePage
exports.Search			=Search
exports.MasteryBook		=MasteryBook
exports.SpectatorInfo	=SpectatorInfo
