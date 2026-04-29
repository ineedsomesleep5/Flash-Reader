const STRIP_RE = /^[.,!?;:"""'''()[\]{}\-–—]+|[.,!?;:"""'''()[\]{}\-–—]+$/g;
const SENTENCE_END_RE = /[.!?][""']?$/;
const CLAUSE_END_RE = /[,;:][""']?$/;

export function tokenize(text) {
  return text
    .split(/\s+/)
    .filter(w => w.length > 0)
    .map(raw => {
      const stripped = raw.replace(STRIP_RE, '') || raw;
      const len = stripped.length;

      let multiplier = 1;
      if (SENTENCE_END_RE.test(raw)) multiplier = 2.5;
      else if (CLAUSE_END_RE.test(raw)) multiplier = 1.5;
      else if (len > 12) multiplier = 1.4;
      else if (len > 8) multiplier = 1.2;

      // Optimal recognition point: the letter the eye should fixate on
      const orp = len <= 1 ? 0 : len <= 5 ? 1 : len <= 9 ? 2 : 3;

      return { raw, stripped, multiplier, orp };
    });
}
