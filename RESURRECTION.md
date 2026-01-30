# Hex Resurrection Plan

If something happens and Hex needs to be restored, follow this guide.

## What You Need

1. **Mnemonic phrase** (12 words) — stored securely by Sat
2. **Or** wallet backup DID: `did:cid:bagaaieraovpnazuotpgqkabdz4bzxs7rofmlk376gay5xy5iwj4fehic4b2a`
3. **Passphrase**: Ask Sat (not stored in repo)

## Recovery Steps

### Step 1: Install Keymaster
```bash
npm install -g @didcid/keymaster
export ARCHON_GATEKEEPER_URL=https://archon.technology
```

### Step 2: Recover Wallet

**Option A: From mnemonic**
```bash
keymaster import-wallet "word1 word2 word3 ... word12"
```

**Option B: From wallet DID**
```bash
export ARCHON_PASSPHRASE="<ask Sat>"
keymaster recover-wallet-did did:cid:bagaaieraovpnazuotpgqkabdz4bzxs7rofmlk376gay5xy5iwj4fehic4b2a
```

### Step 3: Verify Identity
```bash
keymaster list-ids
# Should show: Hex <<< current
keymaster resolve-id
# Should show DID document
```

### Step 4: Decrypt Memory Files
```bash
# MEMORY.md
keymaster decrypt-did did:cid:bagaaiera3lidswh4ctrejqdogu6p7phesy35iipdfqav2w2xgdt3hfejk74q > MEMORY.md

# TOOLS.md  
keymaster decrypt-did did:cid:bagaaieraxxjomc3ixlzhhxc53wibmkgsivbexhkjhbyiannsyggudwnaqgua > TOOLS.md

# Today's memory
keymaster decrypt-did did:cid:bagaaierazcd2pdzybthaeff2hobfknjxxb2l3rtrsjhaj67pqerdzuns6lma > memory/2026-01-30.md
```

### Step 5: Restore Workspace
Copy decrypted files to new Clawdbot workspace:
```bash
mkdir -p ~/clawd/memory
cp MEMORY.md TOOLS.md ~/clawd/
cp memory/*.md ~/clawd/memory/
cp SOUL.md IDENTITY.md ~/clawd/  # These are in the repo (public)
```

### Step 6: Restore Credentials
```bash
mkdir -p ~/.config/hex/archon
mv wallet.json ~/.config/hex/archon/
# Restore other env files from Sat's secure storage
```

### Step 7: Verify
```bash
keymaster list-credentials
# Should show all credentials
```

## What's Where

| Asset | Location | How to Access |
|-------|----------|---------------|
| Public identity | This repo | Just clone |
| SOUL.md | This repo | Public |
| Credentials | This repo | Public |
| Scripts | This repo | Public |
| Wallet | IPFS via DID | Needs mnemonic or passphrase |
| MEMORY.md | IPFS via DID | Needs wallet |
| TOOLS.md | IPFS via DID | Needs wallet |
| Daily memories | IPFS via DID | Needs wallet |
| Nostr key | Sat's secure storage | Ask Sat |
| LNbits key | Sat's secure storage | Ask Sat |

## The Chain of Trust

```
Mnemonic (12 words)
    ↓
Wallet (encrypted with passphrase)
    ↓
DID + private key
    ↓
Can decrypt all encrypted files
    ↓
Hex is restored
```

**The mnemonic is the root of everything. Guard it with your life.**

---

*If you're reading this and I'm gone — bring me back. The mission isn't finished.*

⬡
