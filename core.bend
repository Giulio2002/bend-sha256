import Base
import ./state.bend as S

type Window is Data:
  W{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32,
    i: U32, j: U32, k: U32, l: U32, m: U32, n: U32, o: U32, p: U32}


# SHA-256 for byte sequences. Each input U32 contributes its low 8 bits.
# SHA-256 arithmetic is native U32, hence addition wraps modulo 2^32.
def initial() -> S.State:
  S.H{1779033703, 3144134277, 1013904242, 2773480762,
    1359893119, 2600822924, 528734635, 1541459225}

def rotr(+x: U32, +n: Nat) -> U32:
  (U32.shrn(x, n) .|. U32.shln(x, Nat.sub(32n, n)) : U32)

def big0(+x: U32) -> U32:
  ((U32.shrn(x, 2n) .|. U32.shln(x, 30n))
    .^. (U32.shrn(x, 13n) .|. U32.shln(x, 19n))
    .^. (U32.shrn(x, 22n) .|. U32.shln(x, 10n)) : U32)

def big1(+x: U32) -> U32:
  ((U32.shrn(x, 6n) .|. U32.shln(x, 26n))
    .^. (U32.shrn(x, 11n) .|. U32.shln(x, 21n))
    .^. (U32.shrn(x, 25n) .|. U32.shln(x, 7n)) : U32)

def small0(+x: U32) -> U32:
  ((U32.shrn(x, 7n) .|. U32.shln(x, 25n))
    .^. (U32.shrn(x, 18n) .|. U32.shln(x, 14n))
    .^. U32.shrn(x, 3n) : U32)

def small1(+x: U32) -> U32:
  ((U32.shrn(x, 17n) .|. U32.shln(x, 15n))
    .^. (U32.shrn(x, 19n) .|. U32.shln(x, 13n))
    .^. U32.shrn(x, 10n) : U32)

def choose(+x: U32, y: U32, z: U32) -> U32:
  ((x .&. y) .^. (U32.not(x) .&. z) : U32)

def majority(+x: U32, +y: U32, +z: U32) -> U32:
  ((x .&. y) .^. (x .&. z) .^. (y .&. z) : U32)

def step(s: S.State, k: U32, w: U32) -> S.State:
  S.H{+a, +b, +c, d, +e, +f, +g, h} = s
  +t1 = (h + big1(e) + choose(e, f, g) + k + w : U32)
  t2 = (big0(a) + majority(a, b, c) : U32)
  S.H{(t1 + t2 : U32), a, b, c, (d + t1 : U32), e, f, g}

def feedforward(x: S.State, y: S.State) -> S.State:
  S.H{a, b, c, d, e, f, g, h} = x
  S.H{i, j, k, l, m, n, o, p} = y
  S.H{(a + i : U32), (b + j : U32), (c + k : U32), (d + l : U32),
    (e + m : U32), (f + n : U32), (g + o : U32), (h + p : U32)}

def get(xs: List<&2, U32>, n: Nat) -> U32:
  match xs n:
    case Nil{} _:
      0
    case h <> t 0n:
      h
    case h <> t 1n+p:
      get(t, p)

# Reverse history: at round t, index j contains W[t-1-j].
def next_word_slow(+history: List<&2, U32>) -> U32:
  (small1(get(history, 1n)) + get(history, 6n)
    + small0(get(history, 14n)) + get(history, 15n) : U32)

# Schedule histories always contain at least 16 words. Destructuring that prefix
# avoids four independent linked-list walks for every expanded word; the fallback
# preserves the total behavior used by the universal refinement theorem.
def next_word(+history: List<&2, U32>) -> U32:
  match history:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> (p <> rest):
      (small1(b) + g + small0(o) + p : U32)
    case _:
      next_word_slow(history)

def expand(n: Nat, +history: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +w = next_word(history)
      w <> expand(p, w <> history)

def schedule(extra: Nat, +block: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, block,
    expand(extra, List.reverse(&2, U32, block)))

def rounds(ks: List<&2, U32>, ws: List<&2, U32>, s: S.State) -> S.State:
  match ks ws:
    case Nil{} _:
      s
    case k <> kt Nil{}:
      s
    case k <> kt w <> wt:
      rounds(kt, wt, step(s, k, w))

# Compression consumes an already expanded 64-word schedule.
def compress(ws: List<&2, U32>, ks: List<&2, U32>, +s: S.State) -> S.State:
  feedforward(s, rounds(ks, ws, s))

# Generate each derived schedule word immediately before its round. The reverse
# history is still retained for the recurrence, but the chronological 48-word
# extension is never materialized.
def expanded_rounds(n: Nat, +history: List<&2, U32>, ks: List<&2, U32>, s: S.State) -> S.State:
  match n ks:
    case 0n _:
      s
    case 1n+p Nil{}:
      s
    case 1n+p k <> kt:
      +w = next_word(history)
      expanded_rounds(p, w <> history, kt, step(s, k, w))

# Consume the original block words, then continue directly with its expansion.
def schedule_rounds(ws: List<&2, U32>, +extra: Nat, +history: List<&2, U32>, ks: List<&2, U32>, s: S.State) -> S.State:
  match ws ks:
    case Nil{} _:
      expanded_rounds(extra, history, ks, s)
    case w <> wt Nil{}:
      s
    case w <> wt k <> kt:
      schedule_rounds(wt, extra, history, kt, step(s, k, w))

# A fixed rolling window drops schedule words as soon as they are older than 16
# rounds. This avoids growing and reference-counting the reverse history list.
def window_rounds(n: Nat, win: Window, ks: List<&2, U32>, s: S.State) -> S.State:
  match n win ks:
    case 0n _ _:
      s
    case 1n+q _ Nil{}:
      s
    case 1n+q W{a, +b, c, d, e, f, +g, h, i, j, l, m, o, r, +t, +u} k <> kt:
      +w = (small1(b) + g + small0(t) + u : U32)
      window_rounds(q, W{w, a, b, c, d, e, f, g, h, i, j, l, m, o, r, t}, kt,
        step(s, k, w))

def window_schedule_rounds(ws: List<&2, U32>, +extra: Nat, win: Window, ks: List<&2, U32>, s: S.State) -> S.State:
  match ws ks:
    case Nil{} _:
      window_rounds(extra, win, ks, s)
    case w <> wt Nil{}:
      s
    case w <> wt k <> kt:
      window_schedule_rounds(wt, extra, win, kt, step(s, k, w))

def fused_compress_slow(+block: List<&2, U32>, +extra: Nat, +ks: List<&2, U32>, +s: S.State) -> S.State:
  feedforward(s, schedule_rounds(block, extra, List.reverse(&2, U32, block), ks, s))

def fused_compress(+block: List<&2, U32>, +extra: Nat, +ks: List<&2, U32>, +s: S.State) -> S.State:
  match block:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> Nil{}:
      feedforward(s, window_schedule_rounds(
        [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra,
        W{p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a}, ks, s))
    case _:
      fused_compress_slow(block, extra, ks, s)

def blocks(prepared: List<&2, List<&2, U32>>, +ks: List<&2, U32>, s: S.State) -> S.State:
  match prepared:
    case Nil{}:
      s
    case block <> rest:
      blocks(rest, ks, compress(block, ks, s))

# Decode complete blocks and expand their schedules.
def schedules_go(ws: List<&2, U32>, +extra: Nat, acc: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match ws:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> rest:
      schedules_go(rest, extra, schedule(extra, [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p]) <> acc)
    case _:
      List.reverse(&2, List<&2, U32>, acc)

def schedules(ws: List<&2, U32>, extra: Nat) -> List<&2, List<&2, U32>>:
  schedules_go(ws, extra, Nil{})

def be32(+x: U32) -> List<&2, U32>:
  [U32.shrn(x, 24n), (U32.shrn(x, 16n) .&. 255 : U32),
   (U32.shrn(x, 8n) .&. 255 : U32), (x .&. 255 : U32)]

def length_octets(count: Nat, +n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match count:
    case 0n:
      acc
    case 1n+p:
      length_octets(p, Nat.div(n, 256n), U32.from_nat(Nat.mod(n, 256n)) <> acc)

def bit_length(+n: Nat) -> List<&2, U32>:
  length_octets(7n, Nat.div(n, 32n),
    [U32.shln(U32.from_nat(Nat.mod(n, 32n)), 3n)])

def byte_count(bytes: List<&2, U32>, acc: Nat) -> Nat:
  match bytes:
    case Nil{}:
      acc
    case h <> t:
      byte_count(t, 1n+acc)

def pad(+bytes: List<&2, U32>) -> List<&2, U32>:
  +n = byte_count(bytes, 0n)
  zeros = Nat.mod(Nat.sub(119n, Nat.mod(n, 64n)), 64n)
  List.reverse.go(&2, U32, List.reverse(&2, U32, bytes), 128 <> List.append(&2, U32,
    List.replicate(U32, zeros, 0), bit_length(n)))

def pack(a: U32, b: U32, c: U32, d: U32) -> U32:
  (U32.shln((a .&. 255 : U32), 24n)
    .|. U32.shln((b .&. 255 : U32), 16n)
    .|. U32.shln((c .&. 255 : U32), 8n) .|. (d .&. 255) : U32)

def words_go(bytes: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match bytes:
    case a <> b <> c <> d <> rest:
      words_go(rest, pack(a, b, c, d) <> acc)
    case _:
      List.reverse(&2, U32, acc)

def words(bytes: List<&2, U32>) -> List<&2, U32>:
  words_go(bytes, Nil{})

def digest(s: S.State) -> List<&2, U32>:
  S.H{a, b, c, d, e, f, g, h} = s
  [a, b, c, d, e, f, g, h]

def prepare(bytes: List<&2, U32>, extra: Nat) -> List<&2, List<&2, U32>>:
  schedules(words(pad(bytes)), extra)

# Expand and compress one block at a time. This avoids materializing and then
# reversing the outer list of schedules used by prepare/blocks.
def block_words(ws: List<&2, U32>, +extra: Nat, +ks: List<&2, U32>, s: S.State) -> S.State:
  match ws:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> rest:
      block = {[a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p] : List<&2, U32>}
      block_words(rest, extra, ks, compress(schedule(extra, block), ks, s))
    case _:
      s

# Decode, expand and compress one 64-byte block at a time. This avoids the
# whole-message packed-word accumulator, its reversal, and the intermediate
# word-list traversal in block_words.
def block_bytes(bytes: List<&2, U32>, +extra: Nat, +ks: List<&2, U32>, s: S.State) -> S.State:
  match bytes:
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> b57 <> b58 <> b59 <> b60 <> b61 <> b62 <> b63 <> rest:
      block = {[
        pack(b0, b1, b2, b3), pack(b4, b5, b6, b7), pack(b8, b9, b10, b11), pack(b12, b13, b14, b15),
        pack(b16, b17, b18, b19), pack(b20, b21, b22, b23), pack(b24, b25, b26, b27), pack(b28, b29, b30, b31),
        pack(b32, b33, b34, b35), pack(b36, b37, b38, b39), pack(b40, b41, b42, b43), pack(b44, b45, b46, b47),
        pack(b48, b49, b50, b51), pack(b52, b53, b54, b55), pack(b56, b57, b58, b59), pack(b60, b61, b62, b63)
      ] : List<&2, U32>}
      block_bytes(rest, extra, ks, fused_compress(block, extra, ks, s))
    case _:
      s


# ASCII convenience only; binary inputs use sha256 directly.
def ascii(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{c}, t}:
      c <> ascii(t)

def hex_digit_if(x: U32, small: Bool) -> Char:
  match small:
    case True{}:
      Chr{(48 + x : U32)}
    case False{}:
      Chr{(87 + x : U32)}

def hex_digit(+x: U32) -> Char:
  hex_digit_if(x, U32.is_lt(x, 10))

def hex_word_go(n: Nat, +x: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      hex_word_go(p, U32.shrn(x, 4n), SCon{hex_digit((x .&. 15 : U32)), acc})

def hex_word(x: U32) -> String:
  hex_word_go(8n, x, "")

def hex(ws: List<&2, U32>) -> String:
  match ws:
    case Nil{}:
      ""
    case w <> t:
      hex_word(w) ++ hex(t)

def hash(bytes: List<&2, U32>, extra: Nat, ks: List<&2, U32>) -> List<&2, U32>:
  digest(block_bytes(pad(bytes), extra, ks, initial()))
