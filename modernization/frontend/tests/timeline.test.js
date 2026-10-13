import test from 'node:test'
import assert from 'node:assert/strict'
import { timelineActiveIndex } from '../src/utils/timeline.js'

test('uses the explicitly current stage', () => {
  assert.equal(timelineActiveIndex([
    { status: 'done' },
    { status: 'current' },
    { status: 'pending' }
  ]), 1)
})

test('chooses the stage after the last completed stage when none is current', () => {
  assert.equal(timelineActiveIndex([
    { status: 'done' },
    { status: 'done' },
    { status: 'pending' }
  ]), 2)
})

test('returns zero for missing, malformed, and pending-only timelines', () => {
  assert.equal(timelineActiveIndex(), 0)
  assert.equal(timelineActiveIndex({}), 0)
  assert.equal(timelineActiveIndex([{ status: 'pending' }, null]), 0)
})
