import Base
import ./state.bend as S
import ./core.bend as C
import ./fips.bend as F
import ./list_proofs.bend as L
import ./padding_proof.bend as Padding

law count_acc:
  for +xs: List<&2, U32>
  for +acc: Nat
  {C.byte_count(xs, acc) == Nat.add(List.length(&2, U32, xs), acc) : Nat}

def count_acc(xs, acc):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      Equal.trans(Nat, C.byte_count(t, 1n+acc),
        Nat.add(List.length(&2, U32, t), 1n+acc),
        1n+Nat.add(List.length(&2, U32, t), acc),
        count_acc(t, 1n+acc), L.add_succ(List.length(&2, U32, t), acc))

law count_correct:
  for +xs: List<&2, U32>
  {C.byte_count(xs, 0n) == List.length(&2, U32, xs) : Nat}

def count_correct(xs):
  Equal.trans(Nat, C.byte_count(xs, 0n), Nat.add(List.length(&2, U32, xs), 0n),
    List.length(&2, U32, xs), count_acc(xs, 0n), L.add_zero(List.length(&2, U32, xs)))

law octets_correct:
  for +width: Nat
  for +n: Nat
  for +acc: List<&2, U32>
  {C.length_octets(width, n, acc) == List.append(&2, U32, F.octets(width, n), acc) : List<&2, U32>}

def octets_correct(width, n, acc):
  match width:
    case 0n:
      {==}
    case 1n+p:
      %L.append_assoc_reverse(U32, F.octets(p, Nat.div(n, 256n)),
        [U32.from_nat(Nat.mod(n, 256n))], acc) :
        {C.length_octets(p, Nat.div(n, 256n), U32.from_nat(Nat.mod(n, 256n)) <> acc) == _ : List<&2, U32>}
      octets_correct(p, Nat.div(n, 256n), U32.from_nat(Nat.mod(n, 256n)) <> acc)

law length_correct:
  for +n: Nat
  {C.bit_length(n) == F.length_field(n) : List<&2, U32>}

def length_correct(n):
  octets_correct(7n, Nat.div(n, 32n), [U32.shln(U32.from_nat(Nat.mod(n, 32n)), 3n)])

law pad_correct:
  for +xs: List<&2, U32>
  {C.pad(xs) == F.pad(xs) : List<&2, U32>}

def pad_correct(xs):
  %count_correct(xs) :
    {C.pad(xs) == List.append(&2, U32, xs, F.padding_suffix(_)) : List<&2, U32>}
  %Padding.zeros_correct(Nat.mod(C.byte_count(xs, 0n), 64n)) :
    {C.pad(xs) == List.append(&2, U32, xs, 128 <> List.append(&2, U32,
      List.replicate(U32, _, 0), F.length_field(C.byte_count(xs, 0n)))) : List<&2, U32>}
  %length_correct(C.byte_count(xs, 0n)) :
    {C.pad(xs) == List.append(&2, U32, xs, 128 <> List.append(&2, U32,
      List.replicate(U32, Nat.mod(Nat.sub(119n, Nat.mod(C.byte_count(xs, 0n), 64n)), 64n), 0), _)) : List<&2, U32>}
  L.reverse_append(U32, xs, 128 <> List.append(&2, U32,
    List.replicate(U32, Nat.mod(Nat.sub(119n, Nat.mod(C.byte_count(xs, 0n), 64n)), 64n), 0),
    C.bit_length(C.byte_count(xs, 0n))))

law words_acc:
  for +bytes: List<&2, U32>
  for +acc: List<&2, U32>
  {C.words_go(bytes, acc) == List.reverse.go(&2, U32, acc, F.words(bytes)) : List<&2, U32>}

def words_acc(bytes, acc):
  match bytes:
    case a <> b <> c <> d <> rest:
      words_acc(rest, C.pack(a, b, c, d) <> acc)
    case Nil{}:
      {==}
    case a <> Nil{}:
      {==}
    case a <> b <> Nil{}:
      {==}
    case a <> b <> c <> Nil{}:
      {==}

law words_correct:
  for bytes: List<&2, U32>
  {C.words(bytes) == F.words(bytes) : List<&2, U32>}

def words_correct(bytes):
  words_acc(bytes, Nil{})

law nth_correct:
  for xs: List<&2, U32>
  for n: Nat
  {C.get(xs, n) == F.nth(xs, n) : U32}

def nth_correct(xs, n):
  match xs n:
    case Nil{} _:
      {==}
    case h <> t 0n:
      {==}
    case h <> t 1n+p:
      nth_correct(t, p)

law next_correct:
  for +hs: List<&2, U32>
  {C.next_word(hs) == F.recurrence(hs) : U32}

def next_correct(hs):
  %nth_correct(hs, 1n) : {C.next_word(hs) == (F.sigma1(_) + F.nth(hs, 6n) + F.sigma0(F.nth(hs, 14n)) + F.nth(hs, 15n) : U32) : U32}
  %nth_correct(hs, 6n) : {C.next_word(hs) == (F.sigma1(C.get(hs, 1n)) + _ + F.sigma0(F.nth(hs, 14n)) + F.nth(hs, 15n) : U32) : U32}
  %nth_correct(hs, 14n) : {C.next_word(hs) == (F.sigma1(C.get(hs, 1n)) + C.get(hs, 6n) + F.sigma0(_) + F.nth(hs, 15n) : U32) : U32}
  %nth_correct(hs, 15n) : {C.next_word(hs) == (F.sigma1(C.get(hs, 1n)) + C.get(hs, 6n) + F.sigma0(C.get(hs, 14n)) + _ : U32) : U32}
  {==}

law extension_correct:
  for +n: Nat
  for +hs: List<&2, U32>
  {C.expand(n, hs) == F.extension(n, hs) : List<&2, U32>}

def extension_correct(n, hs):
  match n:
    case 0n:
      {==}
    case 1n+p:
      %next_correct(hs) : {C.expand(1n+p, hs) == _ <> F.extension(p, _ <> hs) : List<&2, U32>}
      %extension_correct(p, C.next_word(hs) <> hs) :
        {C.expand(1n+p, hs) == C.next_word(hs) <> _ : List<&2, U32>}
      {==}

law schedule_correct:
  for +extra: Nat
  for +block: List<&2, U32>
  {C.schedule(extra, block) == F.schedule(extra, block) : List<&2, U32>}

def schedule_correct(extra, block):
  Equal.cong(List<&2, U32>, List<&2, U32>, ext => List.append(&2, U32, block, ext),
    C.expand(extra, List.reverse(&2, U32, block)), F.extension(extra, List.reverse(&2, U32, block)),
    extension_correct(extra, List.reverse(&2, U32, block)))

law schedules_acc:
  for +ws: List<&2, U32>
  for +extra: Nat
  for +acc: List<&2, List<&2, U32>>
  {C.schedules_go(ws, extra, acc) == List.reverse.go(&2, List<&2, U32>, acc, F.schedules(ws, extra)) : List<&2, List<&2, U32>>}

def schedules_acc(ws, extra, acc):
  match ws:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> rest:
      %schedule_correct(extra, [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p]) :
        {C.schedules_go(a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> rest, extra, acc) == List.reverse.go(&2, List<&2, U32>, acc, _ <> F.schedules(rest, extra)) : List<&2, List<&2, U32>>}
      schedules_acc(rest, extra, C.schedule(extra, [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p]) <> acc)
    case Nil{}:
      {==}
    case a <> Nil{}:
      {==}
    case a <> b <> Nil{}:
      {==}
    case a <> b <> c <> Nil{}:
      {==}
    case a <> b <> c <> d <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> h <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> Nil{}:
      {==}
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> Nil{}:
      {==}

law schedules_correct:
  for ws: List<&2, U32>
  for extra: Nat
  {C.schedules(ws, extra) == F.schedules(ws, extra) : List<&2, List<&2, U32>>}

def schedules_correct(ws, extra):
  schedules_acc(ws, extra, Nil{})

law prepare_correct:
  for +bytes: List<&2, U32>
  for +extra: Nat
  {C.prepare(bytes, extra) == F.prepare(bytes, extra) : List<&2, List<&2, U32>>}

def prepare_correct(bytes, extra):
  %pad_correct(bytes) :
    {C.prepare(bytes, extra) == F.schedules(F.words(_), extra) : List<&2, List<&2, U32>>}
  %words_correct(C.pad(bytes)) :
    {C.prepare(bytes, extra) == F.schedules(_, extra) : List<&2, List<&2, U32>>}
  schedules_correct(C.words(C.pad(bytes)), extra)

law step_correct:
  for s: S.State
  for k: U32
  for w: U32
  {C.step(s, k, w) == F.step(s, k, w) : S.State}

def step_correct(s, k, w):
  match s:
    case S.H{a, b, c, d, e, f, g, h}:
      {==}

law rounds_correct:
  for +ks: List<&2, U32>
  for +ws: List<&2, U32>
  for +s: S.State
  {C.rounds(ks, ws, s) == F.rounds(ks, ws)(s) : S.State}

def rounds_correct(ks, ws, s):
  match ks ws:
    case Nil{} _:
      {==}
    case k <> kt Nil{}:
      {==}
    case k <> kt w <> wt:
      %step_correct(s, k, w) :
        {C.rounds(kt, wt, C.step(s, k, w)) == F.rounds(kt, wt)(_) : S.State}
      rounds_correct(kt, wt, C.step(s, k, w))

law feedforward_correct:
  for x: S.State
  for y: S.State
  {C.feedforward(x, y) == F.feedforward(x, y) : S.State}

def feedforward_correct(x, y):
  match x y:
    case S.H{a, b, c, d, e, f, g, h} S.H{i, j, k, l, m, n, o, p}:
      {==}

law compression_correct:
  for +ws: List<&2, U32>
  for +ks: List<&2, U32>
  for +s: S.State
  {C.compress(ws, ks, s) == F.compress(ws, ks, s) : S.State}

def compression_correct(ws, ks, s):
  %feedforward_correct(s, F.rounds(ks, ws)(s)) : {C.compress(ws, ks, s) == _ : S.State}
  Equal.cong(S.State, S.State, r => C.feedforward(s, r),
    C.rounds(ks, ws, s), F.rounds(ks, ws)(s), rounds_correct(ks, ws, s))

law blocks_correct:
  for +ws: List<&2, List<&2, U32>>
  for +ks: List<&2, U32>
  for +s: S.State
  {C.blocks(ws, ks, s) == F.blocks(ws, ks)(s) : S.State}

def blocks_correct(ws, ks, s):
  match ws:
    case Nil{}:
      {==}
    case block <> rest:
      %compression_correct(block, ks, s) :
        {C.blocks(rest, ks, C.compress(block, ks, s)) == F.blocks(rest, ks)(_) : S.State}
      blocks_correct(rest, ks, C.compress(block, ks, s))

law digest_correct:
  for s: S.State
  {C.digest(s) == F.digest(s) : List<&2, U32>}

def digest_correct(s):
  match s:
    case S.H{a, b, c, d, e, f, g, h}:
      {==}

# Unlike the old theorem, there is NO arbitrary preprocessing parameter.
# This proves the actual implementation pipeline against the independent one.
law hash_correct:
  for +bytes: List<&2, U32>
  for +extra: Nat
  for +ks: List<&2, U32>
  {C.hash(bytes, extra, ks) == F.hash(bytes, extra, ks) : List<&2, U32>}

def hash_correct(bytes, extra, ks):
  %prepare_correct(bytes, extra) :
    {C.hash(bytes, extra, ks) == F.digest(F.blocks(_, ks)(F.initial())) : List<&2, U32>}
  %digest_correct(F.blocks(C.prepare(bytes, extra), ks)(F.initial())) :
    {C.hash(bytes, extra, ks) == _ : List<&2, U32>}
  Equal.cong(S.State, List<&2, U32>, s => C.digest(s),
    C.blocks(C.prepare(bytes, extra), ks, C.initial()),
    F.blocks(C.prepare(bytes, extra), ks)(C.initial()),
    blocks_correct(C.prepare(bytes, extra), ks, C.initial()))
