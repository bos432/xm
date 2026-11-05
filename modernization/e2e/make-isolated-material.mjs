import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const run = process.argv[2]
if (!run || !/^[a-zA-Z0-9-]+$/.test(run)) throw new Error('Provide isolated run ID')
const target = path.join(path.dirname(fileURLToPath(import.meta.url)), 'reports', 'runs', run, 'materials')
fs.mkdirSync(target, { recursive: true })
const stream = 'BT /F1 12 Tf 50 750 Td (Synthetic QA material - not a formal business document.) Tj ET\n'
const objects = [
  '<< /Type /Catalog /Pages 2 0 R >>',
  '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
  '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  `<< /Length ${Buffer.byteLength(stream)} >>\nstream\n${stream}endstream`
]
let pdf = '%PDF-1.4\n'
const offsets = [0]
for (const [index, object] of objects.entries()) {
  offsets.push(Buffer.byteLength(pdf))
  pdf += `${index + 1} 0 obj\n${object}\nendobj\n`
}
const xref = Buffer.byteLength(pdf)
pdf += `xref\n0 ${offsets.length}\n0000000000 65535 f \n`
pdf += offsets.slice(1).map(offset => `${String(offset).padStart(10, '0')} 00000 n \n`).join('')
pdf += `trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`
for (const name of ['qa-acceptance-application.pdf', 'qa-financial.pdf']) {
  fs.writeFileSync(path.join(target, name), pdf, { flag: 'wx' })
}
console.log(JSON.stringify({ synthetic: true, directory: target, files: 2, bytes_each: Buffer.byteLength(pdf) }))
