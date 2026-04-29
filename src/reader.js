export class Reader {
  constructor({ onWord, onEnd } = {}) {
    this.onWord = onWord;
    this.onEnd = onEnd;
    this.isPlaying = false;
    this._timer = null;
    this._tokens = [];
    this._index = 0;
    this._wpm = 450;
    this._smartPauses = true;
    this._chunkSize = 1;
  }

  get index() { return this._index; }

  play(tokens, startIndex, wpm, smartPauses, chunkSize = 1) {
    if (this.isPlaying) return;
    this._tokens = tokens;
    this._index = Math.max(0, Math.min(startIndex, tokens.length - 1));
    this._wpm = wpm;
    this._smartPauses = smartPauses;
    this._chunkSize = Math.max(1, chunkSize);
    this.isPlaying = true;
    this._loop();
  }

  pause() {
    this.isPlaying = false;
    clearTimeout(this._timer);
    this._timer = null;
    return this._index;
  }

  seekTo(index) {
    this._index = Math.max(0, Math.min(index, this._tokens.length - 1));
    const chunk = this._tokens.slice(this._index, this._index + this._chunkSize);
    if (chunk.length) this.onWord?.(chunk, this._index);
  }

  setWpm(wpm) { this._wpm = wpm; }
  setChunkSize(n) { this._chunkSize = Math.max(1, n); }

  _loop() {
    if (!this.isPlaying) return;
    if (this._index >= this._tokens.length) {
      this.isPlaying = false;
      this.onEnd?.();
      return;
    }
    const chunk = this._tokens.slice(this._index, this._index + this._chunkSize);
    // Use the highest multiplier in the chunk for timing (accounts for punctuation in any word)
    const mult = chunk.reduce((m, t) => Math.max(m, t.multiplier), 1);
    this.onWord?.(chunk, this._index);
    const delay = (60000 / this._wpm) * (this._smartPauses ? mult : 1);
    this._index += this._chunkSize;
    this._timer = setTimeout(() => this._loop(), delay);
  }
}
