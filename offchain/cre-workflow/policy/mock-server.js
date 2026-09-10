const http = require('node:http')

const PORT = Number(process.env.MOCK_PORT || 4600)
const SANCTIONS_KEY = process.env.SECRET_SANCTIONS_API_KEY || 'dev-sanctions-key'

const SANCTIONED = ['0x000000000000000000000000000000000000dead']

const PENDING = [
	{
		srcId: '0xacacacacacacacacacacacacacacacacacacacacacacacacacacacacacacacac',
		sender: '0x00000000000000000000000000000000000000a1',
		recipient: '0x00000000000000000000000000000000000000b2',
		token: '0x00000000000000000000000000000000000000c3',
		value: '250000000000000000000000',
		appNonce: '1',
		deadline: '1757003600',
		submittedAt: '1757000000',
		recentCount: 2,
		recentValueWei: '400000000000000000000000',
	},
	{
		srcId: '0xacacacacacacacacacacacacacacacacacacacacacacacacacacacacacacacac',
		sender: '0x00000000000000000000000000000000000000a1',
		recipient: '0x000000000000000000000000000000000000dead',
		token: '0x00000000000000000000000000000000000000c3',
		value: '100000000000000000000000',
		appNonce: '2',
		deadline: '1757003660',
		submittedAt: '1757000060',
		recentCount: 3,
		recentValueWei: '650000000000000000000000',
	},
]

const send = (res, code, body) => {
	res.writeHead(code, { 'Content-Type': 'application/json' })
	res.end(JSON.stringify(body))
}

http
	.createServer((req, res) => {
		const url = req.url || '/'
		if (url.startsWith('/policy/sanctions')) {
			const auth = req.headers['authorization'] || ''
			if (auth !== `Bearer ${SANCTIONS_KEY}`) return send(res, 401, { error: 'bad key' })
			return send(res, 200, { addresses: SANCTIONED })
		}
		if (url.startsWith('/policy/pending')) {
			return send(res, 200, { settlements: PENDING })
		}
		send(res, 404, { error: 'not found' })
	})
	.listen(PORT, () => console.log(`policy mock server on :${PORT}`))
