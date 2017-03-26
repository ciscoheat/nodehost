require('http').createServer(function (req, res) {
	res.writeHead(200, {'Content-Type': 'text/plain'})
	res.write('Nodehost on port ${port} is working!')
}).listen(${port});