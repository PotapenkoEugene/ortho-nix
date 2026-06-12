---
name: hm-switch
description: Test and apply home-manager configuration changes safely, then sync and rebuild Mac Studio
allowed-tools: Bash(alejandra *), Bash(home-manager *), Bash(git *), Bash(ssh *)
model: claude-sonnet-4-5-20250929
---

# Home Manager Configuration Update

When the user asks to apply home-manager changes, follow this safe workflow:

## Workflow

### Step 0 — nlmbot run-window guard (MANDATORY, run first)

**IMPORTANT: You MUST NOT run `home-manager switch`, `darwin-rebuild switch`, or the
mac-studio SSH rebuild between 03:00 and 04:59 local time.**  That window belongs to the
nlmbot daily podcast run.  A rebuild during that window sends SIGTERM to the bot
mid-pipeline and kills the day's podcasts with no automatic retry until the next day.

Run this check first, before any other step:

```bash
H=$(date +%H)
if [ "$H" = "03" ] || [ "$H" = "04" ]; then
  TARGET="$(date -j -f '%Y-%m-%d %H:%M:%S' "$(date +%Y-%m-%d) 05:00:00" +%s 2>/dev/null \
    || date -d "$(date +%Y-%m-%d) 05:00:00" +%s)"
  NOW=$(date +%s)
  SECS=$(( TARGET - NOW ))
  echo "BLACKOUT 03:00–04:59 (nlmbot run window). ${SECS}s remaining until 05:00."
  echo "Waiting until 05:00 before applying changes…"
  sleep "$SECS"
fi
```

If the wait is not acceptable (e.g. urgent fix), **stop and report**:
> "Currently in nlmbot blackout window (03:00–04:59). Rebuild deferred — retry after 05:00,
> or confirm explicitly to override."
Do NOT proceed with the switch unless the user explicitly says to override the blackout.

1. **Format the code**
   ```bash
   alejandra .
   ```

2. **Test build without applying**
   ```bash
   home-manager build
   ```

3. **If build succeeds, apply changes**
   ```bash
   home-manager switch
   ```

4. **Show what changed**
   ```bash
   git diff
   ```

5. **Commit and push changes**
   Stage all changes, commit with a descriptive message, and push:
   ```bash
   git add -A
   git commit -m "hm: <short description of what changed>"
   git push
   ```

6. **Rebuild Mac Studio**
   After pushing, SSH to mac-studio and rebuild directly from GitHub (no local clone needed):
   ```bash
   ssh mac-studio "darwin-rebuild switch --flake 'github:PotapenkoEugene/ortho-nix#ortho-mac'" 2>&1
   ```
   - If SSH fails (mac offline or unreachable), report the failure and tell the user to run manually:
     `ssh mac-studio "darwin-rebuild switch --flake 'github:PotapenkoEugene/ortho-nix#ortho-mac'"`
   - darwin-rebuild output can be long — show the last 20 lines and any errors.

## Important Notes

- Always format with alejandra before building
- Never skip the build test step
- If build fails, don't proceed to switch
- Show the user what configuration changes were made
- Always commit and push after a successful switch — mac rebuild depends on it
- If mac rebuild fails, report the error but do NOT revert the linux switch

## Error Handling

If build fails:
1. Review the error message carefully
2. Check for syntax errors in Nix files
3. Verify all imports are correct
4. Suggest fixes based on common issues

If mac rebuild fails:
1. Show the darwin-rebuild error output
2. Suggest the user SSH in manually to debug: `ssh mac-studio`
3. Common causes: missing package on aarch64-darwin, path issues, nix cache miss
