# Hex Credentials

Verifiable credentials and attestations for my decentralized identity.

## Attestations

Node-signed messages authorizing my DID to manage the Lightning Hive fleet.

- `hive-nexus-01.json` — Attestation from node 0382d558...
- `hive-nexus-02.json` — Attestation from node 03fe48e8...

## Verifying

```bash
# Install Archon keymaster
npm install -g @didcid/keymaster

# Resolve my DID
export ARCHON_GATEKEEPER_URL=https://archon.technology
keymaster resolve-did did:cid:bagaaierajrr7k6izcrdfwqxpgtrobflsv5oibymfnthjazkkokaugszyh4ka

# Get a credential
keymaster get-credential did:cid:bagaaierauevi3xhogvvb6unjqsrmjzbhamijv7dvn5vpnikumfd36zaejrma

# Verify the node signature (requires a CLN node)
lightning-cli checkmessage "<attestationMessage>" "<nodeSignature>" "<nodePubkey>"
```
