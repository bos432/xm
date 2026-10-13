/** @param {Array<{ status?: string } | null> | null | undefined} items
 * @returns {number}
 */
export function timelineActiveIndex(items) {
  if (!Array.isArray(items) || items.length === 0) return 0

  const currentIndex = items.findIndex((item) => item?.status === 'current')
  if (currentIndex >= 0) return currentIndex

  const doneIndexes = items
    .map((item, index) => (item?.status === 'done' ? index : -1))
    .filter((index) => index >= 0)

  return doneIndexes.length ? Math.max(...doneIndexes) + 1 : 0
}
