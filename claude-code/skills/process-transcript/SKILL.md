---
name: process-transcript
description: Process whisper-stream transcripts and convert to structured notes
allowed-tools: Read, Write, Bash(ls *), Bash(grep *)
model: claude-sonnet-4-5-20250929
argument-hint: "[transcript-file]"
---

# Whisper Transcript Processor

Process transcribed speech from whisper-stream and convert to structured notes.

## Usage

```
/process-transcript                          # Process latest transcript
/process-transcript recording-2026-02-02.txt # Process specific file
```

## Workflow

1. **Find the transcript**
   - If $ARGUMENTS provided, use that file
   - Otherwise, find the latest in ~/Orthidian/transcripts/

2. **Read the transcript**
   ```bash
   cat ~/Orthidian/transcripts/$ARGUMENTS
   ```

3. **Analyze and extract**
   - Main topics discussed
   - Action items and tasks
   - Key decisions or insights
   - Questions or follow-ups needed

4. **Format as structured note**
   Create an Obsidian-compatible markdown note with:
   - Title based on content
   - Date/time metadata
   - Organized sections:
     - ## Summary (2-3 sentences)
     - ## Key Points (bullet list)
     - ## Action Items (checklist format [ ])
     - ## Notes (detailed points)
     - ## Follow-up (questions or next steps)

5. **Save the processed note**
   - Save to ~/Orthidian/processed-transcripts/
   - Use naming: `processed-YYYY-MM-DD-HHMM.md`
   - Keep original transcript unchanged

## Output Format Example

```markdown
# Meeting Notes - Project Discussion

**Date:** 2026-02-02 14:30
**Source:** recording-2026-02-02-1430.txt

## Summary

Discussion about implementing new authentication system. Decided to use JWT tokens and add rate limiting.

## Key Points

- Current auth system is vulnerable
- Need to implement JWT with refresh tokens
- Add rate limiting: 100 requests per minute
- Target completion: end of sprint

## Action Items

- [ ] Research JWT libraries for Python
- [ ] Design rate limiting strategy
- [ ] Update API documentation
- [ ] Schedule security review

## Notes

- Team prefers JWT over session-based auth for scalability
- Rate limiting should be configurable per user tier
- Need to maintain backward compatibility for 2 weeks

## Follow-up

- What database should we use for refresh tokens?
- Do we need separate rate limits for different endpoints?
```

## Tips

- Preserve technical terms and commands exactly as spoken
- If transcript is unclear, note ambiguous sections
- Extract URLs or file paths mentioned
- Identify speaker intentions even if words are imperfect
