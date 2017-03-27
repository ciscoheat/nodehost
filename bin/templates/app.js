require('http').createServer(function (req, res) {
	console.log(req.connection.remoteAddress + ' GET ' + 200)
	res.writeHead(200, {'Content-Type': 'text/html'})
	res.end('Nodehost for ${host} on port ${port} is working!\n')
}).listen(${port}, function(err) {
	if(err) console.err(err)
	else console.log('Nodehost for ${host} is listening on port ${port}')
});
