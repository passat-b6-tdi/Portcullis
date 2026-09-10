import { cre, hexToBase64, ok, text, type TeeRuntime } from '@chainlink/cre-sdk'
import { encodeAbiParameters, keccak256, parseAbiParameters } from 'viem'
import { z } from 'zod'

export const configSchema = z.object({
	schedule: z.string(),
	pendingUrl: z.string(),
	sanctionsUrl: z.string(),
	sanctionsSecretId: z.string(),
	velocityMaxCount: z.number(),
	velocityMaxValueWei: z.string(),
	guardAddress: z.string(),
	chainId: z.number(),
	consumerAddress: z.string().optional(),
	chainSelectorName: z.string().optional(),
})
type Config = z.infer<typeof configSchema>

// verdict codes match CrePolicyConsumer / the CRE report:
// 1 ALLOW,
// 2 DENY,
// 3 MANUAL_REVIEW.
const ALLOW = 1
const DENY = 2
const REVIEW = 3

const RISK_SENDER_SANCTIONED = 1 << 0
const RISK_RECIPIENT_SANCTIONED = 1 << 1
const RISK_VELOCITY = 1 << 2

type PendingSettlement = {
	srcId: `0x${string}`
	sender: `0x${string}`
	recipient: `0x${string}`
	token: `0x${string}`
	value: string
	appNonce: string
	deadline: string
	submittedAt: string
	recentCount: number
	recentValueWei: string
}

const settlementHash = (s: PendingSettlement, cfg: Config): `0x${string}` =>
	keccak256(
		encodeAbiParameters(
			parseAbiParameters(
				'uint256 chainId, address guard, bytes32 srcId, address recipient, address token, uint256 value, uint256 appNonce, uint256 deadline',
			),
			[
				BigInt(cfg.chainId),
				cfg.guardAddress as `0x${string}`,
				s.srcId,
				s.recipient,
				s.token,
				BigInt(s.value),
				BigInt(s.appNonce),
				BigInt(s.deadline),
			],
		),
	)

const decide = (
	s: PendingSettlement,
	sanctioned: Set<string>,
	cfg: Config,
): { verdict: number; riskMask: number } => {
	let riskMask = 0
	if (sanctioned.has(s.sender.toLowerCase())) riskMask |= RISK_SENDER_SANCTIONED
	if (sanctioned.has(s.recipient.toLowerCase())) riskMask |= RISK_RECIPIENT_SANCTIONED

	const overCount = s.recentCount + 1 > cfg.velocityMaxCount
	const overValue = BigInt(s.recentValueWei) + BigInt(s.value) > BigInt(cfg.velocityMaxValueWei)
	if (overCount || overValue) riskMask |= RISK_VELOCITY

	if (riskMask & (RISK_SENDER_SANCTIONED | RISK_RECIPIENT_SANCTIONED)) return { verdict: DENY, riskMask }
	if (riskMask & RISK_VELOCITY) return { verdict: overValue ? DENY : REVIEW, riskMask }
	return { verdict: ALLOW, riskMask }
}

export const onCronTrigger = (runtime: TeeRuntime<Config>): string => {
	const cfg = runtime.config
	const http = new cre.capabilities.HTTPClient()

	const sanctionsKey = runtime.getSecret({ id: cfg.sanctionsSecretId }).result().value
	const sanctionsRes = http
		.sendRequest(runtime, {
			url: cfg.sanctionsUrl,
			method: 'GET',
			multiHeaders: { Authorization: { values: [`Bearer ${sanctionsKey}`] } },
		})
		.result()
	if (!ok(sanctionsRes)) throw new Error(`sanctions fetch failed: ${sanctionsRes.statusCode}`)
	const sanctioned = new Set<string>(
		(JSON.parse(text(sanctionsRes)).addresses as string[]).map((a) => a.toLowerCase()),
	)

	const pendingRes = http.sendRequest(runtime, { url: cfg.pendingUrl, method: 'GET' }).result()
	if (!ok(pendingRes)) throw new Error(`pending fetch failed: ${pendingRes.statusCode}`)
	const pending = JSON.parse(text(pendingRes)).settlements as PendingSettlement[]

	const donRuntime = runtime.usingTheDons()
	const results: Array<{ msgHash: string; verdict: number; riskMask: number }> = []

	for (const s of pending) {
		const msgHash = settlementHash(s, cfg)
		const { verdict, riskMask } = decide(s, sanctioned, cfg)

		const payload = encodeAbiParameters(
			parseAbiParameters('bytes32 msgHash, uint8 verdict, uint8 riskMask, uint64 issuedAt'),
			[msgHash, verdict, riskMask, BigInt(s.submittedAt)],
		)

		donRuntime
			.report({
				encodedPayload: hexToBase64(payload),
				encoderName: 'evm',
				signingAlgo: 'ecdsa',
				hashingAlgo: 'keccak256',
			})
			.result()

		results.push({ msgHash, verdict, riskMask })
	}

	runtime.log(`policy-workflow decided ${results.length} settlement(s)`)
	return JSON.stringify(results)
}

export function initWorkflow(config: Config) {
	const cron = new cre.capabilities.CronCapability()
	return [
		cre.handlerInTee(cron.trigger({ schedule: config.schedule }), onCronTrigger, [
			{ tee: 'nitro', regions: ['us-west-2'] },
		]),
	]
}
