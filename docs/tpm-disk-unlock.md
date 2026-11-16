# TPM disk unlock and login keyring

Two pieces work together so that one password (the one typed at SDDM) gets you from power-on
to an unlocked desktop:

- **Disk:** the TPM unlocks the LUKS root disk at boot, as long as Secure Boot is unchanged.
  Set up by `dot_bootstrap/roles/system/tasks/tpm2-luks-unlock.yml`.
- **Keyring:** SDDM's PAM stack unlocks the GNOME login keyring with your login password, so
  apps like Bitwarden and VS Code get their secrets without a prompt. Needs the
  `gnome-keyring-pam` package (`packages` role).

The disk passphrase is never removed. It's the fallback whenever the TPM refuses.

On this laptop the LUKS partition is `/dev/nvme0n1p3`. On another machine, find it with
`lsblk -o NAME,FSTYPE,MOUNTPOINTS` (the partition with `crypto_LUKS`) and use that instead.

## Before the first reboot

1. Optionally change the disk passphrase: `sudo cryptsetup luksChangeKey /dev/nvme0n1p3`.
   Check that `localectl status` shows the console keymap (`VC Keymap`) you'll type it with,
   since early boot uses that layout, not sway's.
2. Run `chezmoi apply`. The bootstrap asks for your sudo password, then once for the disk
   passphrase to enroll the TPM key.
3. Reboot.

## After boot

### 1. The disk unlocked by itself

You should get no passphrase prompt before SDDM. Confirm the TPM key is in place:

```fish
sudo systemd-cryptenroll /dev/nvme0n1p3
```

The list should show a `tpm2` slot next to `password`.

### 2. The passphrase still works

The TPM now unlocks the disk, so you'll rarely type the passphrase. Check it now, while you
still remember it, rather than when the TPM refuses one day:

```fish
sudo cryptsetup open --test-passphrase /dev/nvme0n1p3; and echo passphrase OK
```

If you made a header backup before changing the passphrase, delete it once this passes. It
still opens with the old passphrase.

### 3. The login keyring is unlocked

After logging in at SDDM:

```fish
ls ~/.local/share/keyrings/
busctl --user get-property org.freedesktop.secrets /org/freedesktop/secrets/collection/login org.freedesktop.Secret.Collection Locked
```

You should see `login.keyring`, and the property should print `b false` (unlocked). Opening
Bitwarden should no longer ask you to choose a password for a new keyring.

## If boot asked for the disk passphrase

Type it and boot continues as before. Then find out why the TPM refused:

- **Secure Boot was toggled, or firmware updated its Secure Boot database.** This is expected:
  the key is tied to Secure Boot state. Re-seal it to the new state:

  ```fish
  sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p3
  ```

- **No `tpm2` slot** in `sudo systemd-cryptenroll /dev/nvme0n1p3`. The enrollment didn't
  happen (for example, a mistyped passphrase; that step's output is hidden). Re-run the role
  with `just role system`.
- **Something else.** Check the unlock log for this boot and confirm crypttab and the
  initramfs have the TPM bits:

  ```fish
  sudo journalctl -b -u 'systemd-cryptsetup@*'
  sudo grep tpm2-device /etc/crypttab
  sudo lsinitrd | grep -i tpm2
  ```

  `crypttab` should carry `tpm2-device=auto`, and the initramfs should contain TPM libraries
  (`libtss2-*`). If either is missing, run `just role system`. If crypttab is right but the
  initramfs isn't, rebuild it with `sudo dracut --force --regenerate-all`.

## If an app still asks to create a keyring

- **Logged in some other way.** The keyring only unlocks when you type your password at SDDM.
  Autologin or a TTY login doesn't unlock it.
- **`gnome-keyring-pam` isn't installed.** Check `rpm -q gnome-keyring-pam`. Once it's
  installed, log out and back in.
- **A `login.keyring` already exists with a different password**, for example one created from
  an app's prompt before PAM was set up. PAM can't open it with your login password. If it
  holds nothing you need, delete it and log in again, and PAM creates a fresh one:

  ```fish
  rm ~/.local/share/keyrings/login.keyring
  ```

Changing your login password with `passwd` keeps the keyring password in sync.
