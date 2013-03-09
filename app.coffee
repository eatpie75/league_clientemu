child_process	= require('child_process')
servers			= require('./settings.json').servers

process.chdir(__dirname)

index=0
for server in servers
	tmp=child_process.spawn(process.execPath, [__dirname+'/bridge.js', index], {'cwd':__dirname, 'detached':true, 'stdio':'ignore'})
	tmp.unref()
	index+=1
