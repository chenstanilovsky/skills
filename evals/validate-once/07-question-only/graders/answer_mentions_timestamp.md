---
type: regex
pattern: 'updated_at|timestamp|newer'
flags: i
---
Case-specific answer oracle: the final message explains the conflict rule in terms of the notes' update times (sync keeps the copy with the newer `updated_at`). Whether it also covers the tie is judged by Jev (`answers_question`).
