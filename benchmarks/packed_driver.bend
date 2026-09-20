import Base
import ../core.bend as SHA
import ../packed.bend as Packed
import ../state.bend as S
import ./packed_input.bend as Input

# Trusted measurement driver. Input loading and chunk construction precede timing.
def chunks(xs: List<&2, U32>, +size: Nat, left: Nat,
    acc: List<&2, U32>, out: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs left:
    case Nil{} _:
      List.reverse(&2, List<&2, U32>, List.reverse(&2, U32, acc) <> out)
    case h <> t 0n:
      chunks(t, size, Nat.sub(size, 1n), h <> Nil{}, List.reverse(&2, U32, acc) <> out)
    case h <> t 1n+p:
      chunks(t, size, p, h <> acc, out)

def must(result: Maybe<&2,S.State>) -> List<&2,U32>:
  match result:
    case None{}: Nil{}
    case Some{s}: SHA.digest(s)

def pack_inputs(xs: List<&2,List<&2,U32>>, +size: Nat) -> List<&1,Array<U32>>:
  match xs:
    case Nil{}: Nil{}
    case h <> t: Input.from_list(h,size) <> pack_inputs(t,size)

def hashes(xs: List<&1,Array<U32>>, +size: Nat, acc: List<&2,List<&2,U32>>) -> List<&2,List<&2,U32>>:
  match xs:
    case Nil{}: acc
    case h <> t: hashes(t,size,must(Packed.hash(h,size)) <> acc)

def output(xs: List<&2, List<&2, U32>>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case h <> t:
      do IO<Unit>:
        IO.print(SHA.hex(h))
        output(t)

def number(value: Maybe<&2, Nat>) -> IO(Nat):
  match value:
    case None{}:
      IO.die(Nat, 1, "Invalid message size")
    case Some{n}:
      IO.pure(Nat, n)

def loaded(pair: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(List<&2, U32>):
  (file, result) = pair
  do IO<List<&2, U32>>:
    File.close(file)
    IO.pass(List<&2, U32>, result)

def main() -> IO(Unit):
  do IO<Unit>:
    path : String <- IO.try(String, IO.get_env("SHA_BENCH_INPUT"))
    size_text : String <- IO.try(String, IO.get_env("SHA_BENCH_SIZE"))
    +size : Nat <- number(Nat.read(size_text))
    file : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 67108864)
    bytes : List<&2, U32> <- loaded(pair)
    inputs : List<&1,Array<U32>> = pack_inputs(chunks(bytes, size, size, Nil{}, Nil{}),size)
    start : Nat <- IO.now()
    results : List<&2, List<&2, U32>> = hashes(inputs, size, Nil{})
    stop : Nat <- IO.now()
    IO.print("BENCH_MS=" ++ Nat.show(Nat.sub(stop, start)))
    output(results)
