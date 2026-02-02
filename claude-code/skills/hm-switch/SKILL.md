---
name: hm-switch
description: Test and apply home-manager configuration changes safely
allowed-tools: Bash(alejandra *), Bash(home-manager *), Bash(git *)
model: claude-sonnet-4-5-20250929
---

# Home Manager Configuration Update

When the user asks to apply home-manager changes, follow this safe workflow:

## Workflow

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

## Important Notes

- Always format with alejandra before building
- Never skip the build test step
- If build fails, don't proceed to switch
- Show the user what configuration changes were made
- Remind user to commit changes if they look good

## Error Handling

If build fails:
1. Review the error message carefully
2. Check for syntax errors in Nix files
3. Verify all imports are correct
4. Suggest fixes based on common issues
