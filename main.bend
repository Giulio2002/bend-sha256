import Base
import ./sha256.bend as SHA

def show(r: Maybe<&1,Array<U32>>) -> String:
  match r:
    case None{}: "invalid length"
    case Some{a}: SHA.hex(a)

def main() -> IO(Unit):
  IO.print(show(SHA.sha256(Array.new(U32,0n,1633837824),3n)))
