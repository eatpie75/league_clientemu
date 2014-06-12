child_process	= require('child_process')
servers			= require('./settings.json').servers
os				= require('os')

process.chdir(__dirname)
running=[]

main=()->
	index=0
	for server in servers
		if "#{server.region}:#{server.username}" not in running
			start_server(index)
		else
			console.log("#{server.region}:#{server.username} already running")
		index+=1

start_server=(index)->
	tmp=child_process.spawn(process.execPath, [__dirname+'/bridge.js', index], {'cwd':__dirname, 'detached':true, 'stdio':'ignore'})
	tmp.unref()

get_matches=(string, regex, index=1)->
	matches=[]
	while match=regex.exec(string)
		matches.push(match[index])
	return matches

get_running=()->
	child_process.exec('pgrep bridge.js -l -f', (error, stdout, stderr)->
		r=/\d{1,6} bridge\.js: (\w*:\S*)/gim
		running=get_matches(stdout, r)
		main()
	)

if os.platform()=='linux'
	get_running()
else
	main()
