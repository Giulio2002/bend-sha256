import LeanSha256

private def hex (bytes : ByteArray) : String := Id.run do
  let alphabet := "0123456789abcdef".toList.toArray
  let mut result := ""
  for b in bytes do
    result := result.push (alphabet[b.toNat / 16]!)
    result := result.push (alphabet[b.toNat % 16]!)
  return result

def main : IO Unit := do
  let some path ← IO.getEnv "SHA_BENCH_INPUT" | throw <| IO.userError "missing input"
  let some sizeText ← IO.getEnv "SHA_BENCH_SIZE" | throw <| IO.userError "missing size"
  let some size := sizeText.toNat? | throw <| IO.userError "invalid size"
  let corpus ← IO.FS.readBinFile path
  if size == 0 || corpus.size % size != 0 then
    throw <| IO.userError "invalid batch"
  let mut inputs : Array ByteArray := #[]
  for i in [:corpus.size / size] do
    inputs := inputs.push (corpus.extract (i * size) ((i + 1) * size))
  let start ← IO.monoNanosNow
  let mut outputs : Array ByteArray := #[]
  for input in inputs do
    outputs := outputs.push (LeanSha256.hash input)
  let stop ← IO.monoNanosNow
  IO.println s!"BENCH_MS={(stop - start).toFloat / 1000000.0}"
  for i in [:outputs.size] do
    IO.println (hex (outputs[outputs.size - 1 - i]!))
