child_process	= require('child_process')
servers			= require('./settings.json').servers

index=0
for server in servers
	tmp=child_process.spawn(process.execPath, ['bridge.js', index], {'detached':true, 'stdio':'ignore'})
	tmp.unref()
	index+=1
