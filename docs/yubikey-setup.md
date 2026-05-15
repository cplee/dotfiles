# YubiKey smart-card auth on macOS

This Mac uses a YubiKey for **sudo**, **screen unlock**, **login window**, **GUI escalation dialogs**, and **Login keychain unlock** via macOS's PIV smart-card support. The PIN entered into macOS dialogs is the YubiKey PIV PIN, not the account password.

This runbook covers two paths:

1. **New Mac, same already-personalized YubiKey** — just pair the account (most common).
2. **Fresh / wiped YubiKey** — initialize PIV first, then pair.

## Prerequisites

- `ykman` is on PATH. The Brewfile in this repo installs it, so `bin/bootstrap.sh` covers it.
- macOS comes with `pam_smartcard.so` already wired into `/etc/pam.d/sudo`. No PAM editing required for the basic flow.
- If you're customizing the sudo stack further (Touch ID, etc.), put your changes in `/etc/pam.d/sudo_local`. That file survives OS updates; `/etc/pam.d/sudo` does not.

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

3. Pair the user account with that hash (replace `<HASH>`):

   ```bash
   sudo sc_auth pair -u $(whoami) -h <HASH>
   ```

   Should print `User was successfully paired (public key hash: <HASH>)` and nothing else.

   If you also see `Failed to store Login keychain unlock key. No suitable key was found on the selected SmartCard.`, slot **9D** wasn't readable. Unplug + replug the YubiKey and re-run — if that still warns, slot 9D needs a key (see [Slot 9D: keychain](#slot-9d-keychain) below).

4. Verify:

   ```bash
   sc_auth identities
   ```

   The identity should now sit under `Paired identities which are used for authentication:` instead of `Unpaired identities:`.

5. Test sudo:

   ```bash
   sudo -k && sudo whoami
   ```

   A macOS dialog should appear asking for the **PIV PIN** rather than your account password.

That's the full per-Mac setup. Screen unlock, login window, and System Settings unlock dialogs will also accept the YubiKey + PIN automatically.

## Slot 9A (authentication)

Only re-create this slot if the YubiKey was wiped or if `ykman piv keys export 9a -` fails — i.e. the slot doesn't have a real keypair behind it. Note: on older PIV firmware, `ykman piv info` may falsely report `Private key type: EMPTY`. Trust the **export** command instead.

```bash
ykman piv keys generate --algorithm ECCP256 9a /tmp/pub-9a.pem
ykman piv certificates generate --subject "CN=$(whoami)" 9a /tmp/pub-9a.pem
rm /tmp/pub-9a.pem
```

Each step prompts for the PIV PIN. After the cert is generated, **unplug + replug** the YubiKey before re-running `sc_auth identities` so macOS picks up the new cert under a fresh CHUID.

## Slot 9D (keychain)

`9D` (KEY_MANAGEMENT) is used by macOS to encrypt the Login keychain unlock token. Without a working 9D key, every smart-card login asks for the account password to unlock the keychain — and you'll see the "Failed to store Login keychain unlock key" warning during pairing.

```bash
ykman piv keys generate --algorithm ECCP256 9d /tmp/pub-9d.pem
ykman piv certificates generate --subject "CN=$(whoami) keychain" 9d /tmp/pub-9d.pem
rm /tmp/pub-9d.pem
```

Then unplug + replug and **unpair + re-pair** so macOS re-runs the keychain-key encryption step:

```bash
sudo sc_auth unpair -u $(whoami)
sudo sc_auth pair -u $(whoami) -h <NEW-HASH-FROM-sc_auth-identities>
```

If pair runs cleanly without the "Failed to store…" warning, 9D is doing its job.

## Full PIV initialization (factory-fresh YubiKey)

Only required when PIV has never been personalized — the factory PIN and PUK are well-known and must be rotated before anything else.

```bash
ykman piv access change-pin                              # default 123456
ykman piv access change-puk                              # default 12345678
ykman piv access change-management-key --generate --protect
```

`--protect` stores the new random management key on the YubiKey itself, gated by the PIV PIN. After this, every PIV write operation prompts for the PIN — you never type or store the management key separately.

Then run the [Slot 9A](#slot-9a-authentication) and [Slot 9D](#slot-9d-keychain) sections, then [Per-Mac setup](#per-mac-setup-same-yubikey-new-mac).

## Gotchas

- **`ykman piv info` may report `Private key type: EMPTY` on older firmware** even when a key is present. Verify with `ykman piv keys export <slot> -` — if a PEM key prints, the slot is fine.
- **CryptoTokenKit caches the token's CHUID.** After any slot regen, `sc_auth identities` and the pair flow may still reference the *old* token state. Unplug and replug to force a re-read.
- **`sc_auth pairing_ui` is not the pair command.** It only controls whether the auto-pair dialog pops on insertion (`-s enable|disable|status`). Manual pairing is `sudo sc_auth pair -u $(whoami) -h <hash>`.
- **PIN is YubiKey-side**, totally separate from the account password.
- **3 wrong PINs locks the slot.** Unblock with `ykman piv access unblock-pin` (uses the PUK). If both PIN and PUK get locked, `ykman piv reset` wipes the PIV applet — you'll need to re-run full initialization.
- **Account password remains a fallback.** Even after pairing, sudo will fall back to password auth if the YubiKey is absent. To force YubiKey-only sudo (lockout risk), customize `/etc/pam.d/sudo_local` — but only do this with a second YubiKey enrolled and a recovery plan, since one lost key would lock you out.
- **SSH / remote sessions don't get PIN prompts** — there's no GUI to enter the PIN. Remote sudo falls back to password auth.

## Recovery quick reference

| Situation | Fix |
|-----------|-----|
| PIN locked (3 wrong tries) | `ykman piv access unblock-pin` (asks for PUK) |
| PUK locked (3 wrong tries on PUK) | `ykman piv reset` → re-run [Full PIV initialization](#full-piv-initialization-factory-fresh-yubikey) |
| Lost YubiKey | Plug in a backup, run full init, run per-Mac setup |
| `sc_auth pair` says "no suitable key" | Unplug + replug; CryptoTokenKit cache was stale |
| Pair printed "Failed to store Login keychain unlock key" | Slot 9D not ready; (re-)run the 9D section, then unpair + re-pair |
| `ykman piv info` shows EMPTY but `keys export` works | Display bug on older PIV firmware; ignore the EMPTY line |
