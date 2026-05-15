---
name: yubikey-setup
description: Configure YubiKey PIV smart-card auth on macOS — sudo, screen unlock, login window, GUI escalation dialogs, and Login keychain unlock. Use when the user wants to pair a YubiKey to a new Mac, regenerate PIV slots 9A or 9D, initialize a factory-fresh YubiKey, or troubleshoot the `sc_auth pair` / "Private key type: EMPTY" / "no suitable key" flow.
---

# YubiKey smart-card auth on macOS

Set up a YubiKey to drive **sudo**, **screen unlock**, **login window**, **GUI escalation dialogs**, and **Login keychain unlock** on macOS via PIV. The PIN entered into the macOS dialogs is the YubiKey PIV PIN, not the account password.

The same YubiKey works on multiple Macs — pair each Mac to the same key. Pair state is per-Mac, key state is per-YubiKey.

## When to use this skill

Most common: pairing an already-personalized YubiKey to a new Mac. Less common: re-creating PIV slots after a wipe, or initializing a factory-fresh YubiKey. The procedure scales down naturally — skip sections that don't apply.

Not covered: Apple's Passwords app (uses LAContext, doesn't accept smart cards), 1Password local-app unlock (also LAContext). The YubiKey can be enrolled as 2FA on the 1Password account separately — that's a web-UI flow at 1password.com, not part of this skill.

## Prerequisites

- `ykman` on PATH (the repo's Brewfile installs it; `bin/bootstrap.sh` covers it).
- macOS already wires `auth sufficient pam_smartcard.so` into `/etc/pam.d/sudo` by default — no PAM editing needed for the basic flow.
- Customize `/etc/pam.d/sudo_local` if layering additional auth (Touch ID, etc.). `sudo_local` survives OS updates; `/etc/pam.d/sudo` does not.

## Per-Mac setup (same YubiKey, new Mac)

1. Plug in the YubiKey.

2. Confirm macOS sees the PIV cert as unpaired:

   ```bash
   sc_auth identities
   ```

   Expected output shape:

   ```
   SmartCard: com.apple.pivtoken:<chuid>
   Unpaired identities:
   <40-CHAR-HEX-HASH>    Certificate For PIV Authentication (<your CN>)
   ```

   Copy the 40-character hash.

3. Pair the user account with that hash:

   ```bash
   sudo sc_auth pair -u $(whoami) -h <HASH>
   ```

   Expected on success: `User was successfully paired (public key hash: <HASH>)` and nothing else.

   If the output also includes `Failed to store Login keychain unlock key. No suitable key was found on the selected SmartCard.`, slot **9D** wasn't readable. Unplug + replug the YubiKey and re-run — if that still warns, slot 9D needs a key (see [Slot 9D: keychain](#slot-9d-keychain)).

4. Verify:

   ```bash
   sc_auth identities
   ```

   The identity now sits under `Paired identities which are used for authentication:` instead of `Unpaired identities:`.

5. Test sudo:

   ```bash
   sudo -k && sudo whoami
   ```

   A macOS dialog should appear asking for the **PIV PIN** rather than the account password.

Screen unlock, login window, and GUI escalation dialogs all pick up the same pairing automatically.

## Slot 9A: authentication

Only re-create this slot if the YubiKey was wiped or `ykman piv keys export 9a -` fails — i.e. the slot doesn't have a real keypair behind it. On older PIV firmware, `ykman piv info` may falsely report `Private key type: EMPTY`. Trust **`ykman piv keys export`** instead: if it prints a PEM public key, the slot is fine.

```bash
ykman piv keys generate --algorithm ECCP256 9a /tmp/pub-9a.pem
ykman piv certificates generate --subject "CN=$(whoami)" 9a /tmp/pub-9a.pem
rm /tmp/pub-9a.pem
```

Each step prompts for the PIV PIN. After the cert is generated, **unplug + replug** the YubiKey before re-running `sc_auth identities` so macOS picks up the new cert under a fresh CHUID.

## Slot 9D: keychain

`9D` (KEY_MANAGEMENT) is used by macOS to encrypt the Login keychain unlock token. Without a working 9D key, every smart-card login asks for the account password to unlock the keychain — and you'll see the "Failed to store Login keychain unlock key" warning during pairing.

```bash
ykman piv keys generate --algorithm ECCP256 9d /tmp/pub-9d.pem
ykman piv certificates generate --subject "CN=$(whoami) keychain" 9d /tmp/pub-9d.pem
rm /tmp/pub-9d.pem
```

Then unplug + replug, and **unpair + re-pair** so macOS re-runs the keychain-key encryption step:

```bash
sudo sc_auth unpair -u $(whoami)
sudo sc_auth pair -u $(whoami) -h <NEW-HASH-FROM-sc_auth-identities>
```

If pair runs cleanly without the "Failed to store…" warning, 9D is doing its job.

## Full PIV initialization (factory-fresh YubiKey)

Required only when PIV has never been personalized — the factory PIN and PUK are well-known and must be rotated before anything else.

```bash
ykman piv access change-pin                              # default 123456
ykman piv access change-puk                              # default 12345678
ykman piv access change-management-key --generate --protect
```

`--protect` stores the new random management key on the YubiKey itself, gated by the PIV PIN. After this, every PIV write operation prompts for the PIN — the management key is never handled separately.

Then run [Slot 9A](#slot-9a-authentication) and [Slot 9D](#slot-9d-keychain), then [Per-Mac setup](#per-mac-setup-same-yubikey-new-mac).

## Gotchas

- **`ykman piv info` may report `Private key type: EMPTY`** on older firmware (5.x) even when a key is present. Verify with `ykman piv keys export <slot> -` — if a PEM key prints, the slot is fine.
- **CryptoTokenKit caches the token's CHUID.** After any slot regeneration, `sc_auth identities` and the pair flow may still reference the *old* token state. **Unplug and replug** to force a re-read.
- **`sc_auth pairing_ui` is not the pair command.** It only controls whether the auto-pair dialog pops on insertion (`-s enable|disable|status`). Manual pairing is `sudo sc_auth pair -u $(whoami) -h <hash>`.
- **PIN is YubiKey-side**, totally separate from the macOS account password.
- **3 wrong PINs locks the slot.** Unblock with `ykman piv access unblock-pin` (uses the PUK). If both PIN and PUK get locked, `ykman piv reset` wipes the PIV applet — re-run [Full PIV initialization](#full-piv-initialization-factory-fresh-yubikey).
- **Account password remains a fallback.** Even after pairing, sudo falls back to password auth if the YubiKey is absent. To force YubiKey-only sudo (lockout risk), customize `/etc/pam.d/sudo_local` — but only with a second YubiKey enrolled and a recovery plan.
- **SSH / remote sessions don't get PIN prompts** — no GUI to enter the PIN. Remote sudo falls back to password.
- **Apple Passwords app and 1Password app unlock don't honor the PIV pairing** — both use Apple's LAContext, which doesn't accept smart cards. Use Touch ID or account password for those.

## Recovery quick reference

| Situation | Fix |
|-----------|-----|
| PIN locked (3 wrong tries) | `ykman piv access unblock-pin` (asks for PUK) |
| PUK locked (3 wrong tries on PUK) | `ykman piv reset` → re-run [Full PIV initialization](#full-piv-initialization-factory-fresh-yubikey) |
| Lost YubiKey | Plug in a backup, run full init, run per-Mac setup |
| `sc_auth pair` says "no suitable key" | Unplug + replug; CryptoTokenKit cache was stale |
| Pair printed "Failed to store Login keychain unlock key" | Slot 9D not ready; (re-)run the 9D section, then unpair + re-pair |
| `ykman piv info` shows EMPTY but `keys export` works | Display bug on older PIV firmware; ignore the EMPTY line |
