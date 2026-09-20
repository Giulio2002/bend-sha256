import Base
import ../core.bend as Core

# Input conversion for tests/benchmarks only; this is outside the timed hash.
def depth(fuel: Nat, c: Cmp, +words: Nat, +cap: Nat, acc: Nat) -> Nat:
  match fuel c:
    case 0n _: acc
    case _ LT{}: acc
    case _ EQ{}: acc
    case 1n+p GT{}:
      depth(p,Nat.cmp(words,Nat.mul(cap,2n)),words,Nat.mul(cap,2n),Nat.add(acc,1n))

def fill(xs: List<&2,U32>, +i: U32, a: Array<U32>) -> Array<U32>:
  match xs:
    case Nil{}: a
    case b0 <> Nil{}: Array.set(U32,a,i,Core.pack(b0,0,0,0))
    case b0 <> b1 <> Nil{}: Array.set(U32,a,i,Core.pack(b0,b1,0,0))
    case b0 <> b1 <> b2 <> Nil{}: Array.set(U32,a,i,Core.pack(b0,b1,b2,0))
    case b0 <> b1 <> b2 <> b3 <> rest:
      fill(rest,U32.inc(i),Array.set(U32,a,i,Core.pack(b0,b1,b2,b3)))

def from_list(xs: List<&2,U32>, length: Nat) -> Array<U32>:
  +words = Nat.div(Nat.add(length,3n),4n)
  fill(xs,0,Array.new(U32,depth(32n,Nat.cmp(words,1n),words,1n,0n),0))

