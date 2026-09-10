import { ethereum, Bytes } from "@graphprotocol/graph-ts";
import {
  SettlementPaid,
  SettlementRejected
} from "../generated/SettlementReceiver/ArcSettlementReceiver";
import { Payout, Rejection } from "../generated/schema";

function evId(event: ethereum.Event): Bytes {
  return event.transaction.hash.concatI32(event.logIndex.toI32());
}

export function handleSettlementPaid(event: SettlementPaid): void {
  const p = new Payout(evId(event));
  p.messageId = event.params.messageId;
  p.recipient = event.params.recipient;
  p.token = event.params.token;
  p.value = event.params.value;
  p.blockNumber = event.block.number;
  p.blockTimestamp = event.block.timestamp;
  p.txHash = event.transaction.hash;
  p.save();
}

export function handleSettlementRejected(event: SettlementRejected): void {
  const r = new Rejection(evId(event));
  r.messageId = event.params.messageId;
  r.blockNumber = event.block.number;
  r.blockTimestamp = event.block.timestamp;
  r.txHash = event.transaction.hash;
  r.save();
}
