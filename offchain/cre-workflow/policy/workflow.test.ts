import { describe, expect, test } from 'bun:test'
import type { TeeRuntime } from '@chainlink/cre-sdk'
import { initWorkflow, onCronTrigger, configSchema } from './workflow'

const CFG = {
	schedule: '0 */1 * * * *',
	pendingUrl: 'http://localhost:4600/policy/pending',
	sanctionsUrl: 'http://localhost:4600/policy/sanctions',
	sanctionsSecretId: 'SANCTIONS_API_KEY',
	velocityMaxCount: 20,
	velocityMaxValueWei: '5000000000000000000000000',
	guardAddress: '0x00000000000000000000000000000000000000ff',
	chainId: 5042002,
}

const KEY = 'dev-sanctions-key'
const CLEAN = '0x00000000000000000000000000000000000000b2'
const SANCTIONED = '0x000000000000000000000000000000000000dead'

const settlement = (over: Partial<Record<string, unknown>> = {}) => ({
	srcId: '0xacacacacacacacacacacacacacacacacacacacacacacacacacacacacacacacac',
	sender: '0x00000000000000000000000000000000000000a1',
	recipient: CLEAN,
	token: '0x00000000000000000000000000000000000000c3',
	value: '250000000000000000000000',
	appNonce: '1',
	deadline: '1757003600',
	submittedAt: '1757000000',
	recentCount: 2,
	recentValueWei: '400000000000000000000000',
	...over,
})

const fakeRuntime = (settlements: unknown[]) => {
	const reports: unknown[] = []
	const runtime = {
		config: CFG,
		getSecret: () => ({ result: () => ({ value: KEY }) }),
		callCapability: ({ payload }: { payload: { url: string; multiHeaders?: Record<string, unknown> } }) => {
			const bodyFor = (url: string) => {
				if (url.includes('/sanctions')) return JSON.stringify({ addresses: [SANCTIONED] })
				if (url.includes('/pending')) return JSON.stringify({ settlements })
				return '{}'
			}
			return {
				result: () => ({ statusCode: 200, body: new TextEncoder().encode(bodyFor(payload.url)) }),
			}
		},
		log: () => {},
		usingTheDons: () => ({
			report: (input: unknown) => {
				reports.push(input)
				return { result: () => ({}) }
			},
		}),
	}
	return { runtime: runtime as unknown as TeeRuntime<typeof CFG>, reports }
}

describe('config', () => {
	test('schema accepts the staging config', () => {
		expect(() => configSchema.parse(CFG)).not.toThrow()
	})
})

describe('onCronTrigger', () => {
	test('ALLOWs a clean settlement and reports it', () => {
		const { runtime, reports } = fakeRuntime([settlement()])
		const out = JSON.parse(onCronTrigger(runtime))
		expect(out).toHaveLength(1)
		expect(out[0].verdict).toBe(1)
		expect(out[0].riskMask).toBe(0)
		expect(reports).toHaveLength(1)
		expect(reports[0]).toMatchObject({ encoderName: 'evm', signingAlgo: 'ecdsa', hashingAlgo: 'keccak256' })
	})

	test('DENYs a settlement to a sanctioned recipient', () => {
		const { runtime } = fakeRuntime([settlement({ recipient: SANCTIONED, appNonce: '2' })])
		const out = JSON.parse(onCronTrigger(runtime))
		expect(out[0].verdict).toBe(2)
		expect(out[0].riskMask & (1 << 1)).toBeTruthy()
	})

	test('DENYs when recent value blows the velocity budget', () => {
		const { runtime } = fakeRuntime([
			settlement({ value: '3000000000000000000000000', recentValueWei: '4000000000000000000000000' }),
		])
		const out = JSON.parse(onCronTrigger(runtime))
		expect(out[0].verdict).toBe(2)
		expect(out[0].riskMask & (1 << 2)).toBeTruthy()
	})

	test('MANUAL_REVIEW when only recent count is over budget', () => {
		const { runtime } = fakeRuntime([settlement({ recentCount: 25 })])
		const out = JSON.parse(onCronTrigger(runtime))
		expect(out[0].verdict).toBe(3)
		expect(out[0].riskMask & (1 << 2)).toBeTruthy()
	})

	test('processes every pending settlement', () => {
		const { runtime, reports } = fakeRuntime([
			settlement(),
			settlement({ recipient: SANCTIONED, appNonce: '2' }),
		])
		const out = JSON.parse(onCronTrigger(runtime))
		expect(out).toHaveLength(2)
		expect(reports).toHaveLength(2)
	})
})

describe('initWorkflow', () => {
	test('registers a TEE cron handler', () => {
		const handlers = initWorkflow(CFG)
		expect(handlers).toHaveLength(1)
		expect(handlers[0].fn).toBe(onCronTrigger)
	})
})
