# Secrets Bootstrap (Mac Only)

`secrets/mac.yaml` is a sops/age-encrypted YAML. It does NOT exist in this repo yet —
it must be created on the Mac Studio after generating the age key.

## One-time setup on the mac

```bash
# 1. Install sops + age temporarily
nix shell nixpkgs#sops nixpkgs#age

# 2. Generate the age key (stored outside the repo — never commit this)
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

# 3. Get the public key
age-keygen -y ~/.config/sops/age/keys.txt
# → age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 4. Update .sops.yaml in the repo with the actual pubkey
# Replace AGE_PUBKEY_REPLACE_ME in ../.sops.yaml

# 5. Create and encrypt the secrets file
cd ~/.config/home-manager
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/mac.yaml
```

Inside the editor, paste and save:
```yaml
tgbot:
    bot_token: "YOUR_BOT_TOKEN_FROM_BOTFATHER"
    owner_user_id: "YOUR_TELEGRAM_NUMERIC_USER_ID"
```

```bash
# 6. Commit both files
git add ../.sops.yaml secrets/mac.yaml
git commit -m "feat: add sops secrets for tgbot deployment"
git push

# 7. Apply the config
darwin-rebuild switch --flake .#ortho-mac
```

After step 7, sops-nix decrypts secrets to `/run/secrets/tgbot/` and the launchd agent starts.

## Rotating secrets

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops secrets/mac.yaml
# edit → save → sops re-encrypts automatically
git add secrets/mac.yaml && git commit -m "chore: rotate tgbot secrets" && git push
darwin-rebuild switch --flake .#ortho-mac
launchctl kickstart -k gui/$(id -u)/com.ortho.tgbot
```
