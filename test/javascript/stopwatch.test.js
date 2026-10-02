import test from "node:test"
import assert from "node:assert/strict"

import { Stopwatch } from "../../app/javascript/lib/stopwatch.js"

const SECOND = 1000
const MINUTE = 60 * SECOND
const HOUR = 60 * MINUTE

function fakeClock() {
  let now = 1_000_000
  return {
    now: () => now,
    advance: (ms) => { now += ms },
  }
}

function watchAt(clock, options = {}) {
  return new Stopwatch({ now: clock.now, ...options })
}

test("starts idle", () => {
  const watch = watchAt(fakeClock())

  assert.equal(watch.running, false)
  assert.equal(watch.onBreak, false)
  assert.equal(watch.workedHours(), 0)
  assert.equal(watch.breakSeconds, 0)
})

test("accumulates worked time", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.start()
  clock.advance(HOUR)

  assert.equal(watch.running, true)
  assert.equal(watch.workedHours(), 1)
})

test("a break pauses the worked clock", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.start()
  clock.advance(HOUR)
  watch.toggleBreak()
  clock.advance(45 * MINUTE)

  assert.equal(watch.onBreak, true)
  assert.equal(watch.workedHours(), 1, "worked time is frozen while on break")
  assert.equal(watch.breakSeconds, 45 * 60)
})

test("resuming continues accumulating worked time", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.start()
  clock.advance(HOUR)
  watch.toggleBreak()
  clock.advance(45 * MINUTE)
  watch.toggleBreak()
  clock.advance(30 * MINUTE)

  assert.equal(watch.onBreak, false)
  assert.equal(watch.workedHours(), 1.5)
})

test("multiple breaks sum", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.start()
  clock.advance(30 * MINUTE)
  watch.toggleBreak()
  clock.advance(10 * MINUTE)
  watch.toggleBreak()
  clock.advance(30 * MINUTE)
  watch.toggleBreak()
  clock.advance(5 * MINUTE)
  watch.toggleBreak()
  clock.advance(15 * MINUTE)

  assert.equal(watch.workedHours(), 1.25)
  assert.equal(watch.breakSeconds, 15 * 60)
})

test("stop writes net worked time, excluding breaks", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.start()
  clock.advance(HOUR)
  watch.toggleBreak()
  clock.advance(55 * MINUTE) // lunch
  watch.toggleBreak()
  clock.advance(45 * MINUTE)
  watch.stop()

  assert.equal(watch.running, false)
  assert.equal(watch.onBreak, false)
  assert.equal(watch.workedHours(), 1.75, "1h45 worked, not the 2h40 elapsed")
})

test("stopping while on break excludes the whole break", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.start()
  clock.advance(30 * MINUTE)
  watch.toggleBreak()
  clock.advance(20 * MINUTE)
  watch.stop()

  assert.equal(watch.workedHours(), 0.5)
  assert.equal(watch.breakSeconds, 20 * 60)
})

test("rounds worked hours to the nearest hundredth", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.start()
  clock.advance(7 * MINUTE + 12 * SECOND) // 0.12h

  assert.equal(watch.workedHours(), 0.12)
})

test("honours a custom rounding step", () => {
  const clock = fakeClock()
  const watch = watchAt(clock, { roundTo: 0.25 })

  watch.start()
  clock.advance(20 * MINUTE) // 0.333h

  assert.equal(watch.workedHours(), 0.25)
})

test("reset clears everything", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.start()
  clock.advance(HOUR)
  watch.toggleBreak()
  clock.advance(MINUTE)
  watch.reset()

  assert.equal(watch.running, false)
  assert.equal(watch.onBreak, false)
  assert.equal(watch.workedHours(), 0)
  assert.equal(watch.breakSeconds, 0)
})

test("ignores start while running and break while stopped", () => {
  const clock = fakeClock()
  const watch = watchAt(clock)

  watch.toggleBreak() // stopped → no-op
  assert.equal(watch.onBreak, false)

  watch.start()
  clock.advance(MINUTE)
  watch.start() // already running → no-op
  clock.advance(MINUTE)

  assert.equal(watch.workedHours(), 0.03)
})
