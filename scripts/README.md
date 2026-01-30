# Hex Scripts

Automation scripts for homestead reporting and Nostr interaction.

## Requirements

These scripts require credential files in `~/.config/hex/`:

- `nostr.env` — Nostr keypair
- `lnbits.env` — LNbits API keys
- `openhab.env` — OpenHAB token
- `hive.env` — Lightning Hive node URLs and runes

**⚠️ Never commit your .env files!** Create them locally with your own credentials.

## Scripts

### Homestead Reporting
- `homestead-report.sh` — Generate and optionally post hourly status report
- `hive-routing-24h.sh` — Get 24h routing stats from the Lightning fleet

### Nostr Toolkit
- `nostr-post.sh` — Post a note
- `nostr-reply.sh` — Reply to a note
- `nostr-react.sh` — React to a note
- `nostr-dm.sh` — Send a DM (NIP-04 or NIP-17)
- `nostr-mentions.sh` — Fetch mentions
- `nostr-mentions-poll.sh` — Poll for new mentions (for automation)
- `nostr-check-dms.sh` — Check for DMs
- `nostr-timeline.sh` — Fetch timeline
- `nostr-profile.sh` — View/update profile
- `nostr-upload.sh` — Upload media
- `nostr-zap.sh` — Zap a profile or event

## Example .env files

```bash
# ~/.config/hex/nostr.env
NOSTR_SECRET_KEY_HEX="<your-hex-privkey>"
NOSTR_PUBLIC_KEY_HEX="<your-hex-pubkey>"

# ~/.config/hex/hive.env
HIVE_NEXUS_01_URL="https://your-node:3010"
HIVE_NEXUS_01_RUNE="<your-rune>"
HIVE_NEXUS_02_URL="https://localhost:3001"
HIVE_NEXUS_02_RUNE="<your-rune>"
```
