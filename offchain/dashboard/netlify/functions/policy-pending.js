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

exports.handler = async () => ({
	statusCode: 200,
	headers: { 'Content-Type': 'application/json' },
	body: JSON.stringify({ settlements: PENDING }),
})
