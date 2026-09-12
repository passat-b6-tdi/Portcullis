const DEMO_KEY = 'portcullis-demo-sanctions-key'
const SANCTIONED = ['0x000000000000000000000000000000000000dead']

exports.handler = async (event) => {
	const auth = event.headers?.authorization || event.headers?.Authorization || ''
	if (auth !== `Bearer ${DEMO_KEY}`) {
		return { statusCode: 401, body: JSON.stringify({ error: 'bad key' }) }
	}
	return {
		statusCode: 200,
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ addresses: SANCTIONED }),
	}
}
