import Base
import ../legacy_model.bend as SHA

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

type Tree is Data:
  Leaf{bytes: List<&2, U32>}
  Branch{left: Tree, right: Tree}

def leaf(xs: List<&2, List<&2, U32>>) -> Tree:
  match xs:
    case Nil{}:
      Leaf{Nil{}}
    case h <> t:
      Leaf{h}

def tree(depth: Nat, +xs: List<&2, List<&2, U32>>, count: Nat) -> Tree:
  match depth:
    case 0n:
      leaf(xs)
    case 1n+p:
      +q = p
      +half = Nat.div(count, 2n)
      Branch{tree(q, List.take(&2, List<&2, U32>, xs, half), half),
        tree(q, List.drop(&2, List<&2, U32>, xs, half), half)}

def hash_tree(input: Tree) -> List<&2, List<&2, U32>>:
  match input:
    case Leaf{bytes}:
      SHA.sha256(bytes) <> Nil{}
    case Branch{left, right}:
      a b = hash_tree(left) hash_tree(right)
      List.append(&2, List<&2, U32>, b, a)

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
    bytes_text : String <- IO.try(String, IO.get_env("SHA_BENCH_BYTES"))
    corpus_bytes : Nat <- number(Nat.read(bytes_text))
    depth_text : String <- IO.try(String, IO.get_env("SHA_BENCH_DEPTH"))
    depth : Nat <- number(Nat.read(depth_text))
    file : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 67108864)
    bytes : List<&2, U32> <- loaded(pair)
    inputs : List<&2, List<&2, U32>> = chunks(bytes, size, size, Nil{}, Nil{})
    input_tree : Tree = tree(depth, inputs, Nat.div(corpus_bytes, size))
    start : Nat <- IO.now()
    results : List<&2, List<&2, U32>> = hash_tree!(input_tree)
    stop : Nat <- IO.now()
    IO.print("BENCH_MS=" ++ Nat.show(Nat.sub(stop, start)))
    output(results)
