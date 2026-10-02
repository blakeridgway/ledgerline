// Pure stopwatch state machine for time entries.
//
// No framework imports: the Stimulus controller is a thin DOM adapter around
// this. Work and break time are accumulated separately so that a break pauses
// the worked clock — and therefore the hours that get billed. `now` is
// injectable so the arithmetic can be tested with a fake clock.
export const DEFAULT_ROUND_TO = 0.01;

export class Stopwatch {
  constructor({ now = () => Date.now(), roundTo = DEFAULT_ROUND_TO } = {}) {
    this.now = now;
    this.roundTo = roundTo;
    this.reset();
  }

  reset() {
    this.running = false;
    this.onBreak = false;
    this.workedBefore = 0;
    this.breakBefore = 0;
    this.segmentStartedAt = null;
  }

  start() {
    if (this.running) return;

    this.running = true;
    this.onBreak = false;
    this.segmentStartedAt = this.now();
  }

  // Ends the session. Whatever has been worked so far is the final total.
  stop() {
    if (!this.running) return;

    this.commitSegment();
    this.running = false;
    this.onBreak = false;
    this.segmentStartedAt = null;
  }

  // Pauses the worked clock and starts a break; pressing again resumes work.
  toggleBreak() {
    if (!this.running) return;

    this.commitSegment();
    this.onBreak = !this.onBreak;
    this.segmentStartedAt = this.now();
  }

  get workedSeconds() {
    return this.workedBefore + this.segmentSeconds(!this.onBreak);
  }

  get breakSeconds() {
    return this.breakBefore + this.segmentSeconds(this.onBreak);
  }

  breakMinutes() {
    return Math.round(this.breakSeconds / 60);
  }

  // Net worked hours, rounded to the configured step (0.01 = hundredths).
  workedHours() {
    const hours = this.workedSeconds / 3600;
    const rounded = Math.round(hours / this.roundTo) * this.roundTo;

    return Number(rounded.toFixed(2));
  }

  // Moves the time elapsed in the current segment into its accumulator so it
  // survives the next segment starting.
  commitSegment() {
    if (this.segmentStartedAt === null) return;

    if (this.onBreak) {
      this.breakBefore += this.segmentSeconds(true);
    } else {
      this.workedBefore += this.segmentSeconds(true);
    }
    this.segmentStartedAt = this.now();
  }

  segmentSeconds(counting) {
    if (!counting || !this.running || this.segmentStartedAt === null) return 0;

    return (this.now() - this.segmentStartedAt) / 1000;
  }
}
