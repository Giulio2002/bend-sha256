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
  match hs:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> (p <> rest):
      {==}
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

law expanded_rounds_correct:
  for +n: Nat
  for +history: List<&2, U32>
  for +ks: List<&2, U32>
  for +s: S.State
  {C.expanded_rounds(n, history, ks, s) == C.rounds(ks, C.expand(n, history), s) : S.State}

def expanded_rounds_correct(n, history, ks, s):
  match n ks:
    case 0n Nil{}:
      {==}
    case 0n k <> kt:
      {==}
    case 1n+p Nil{}:
      {==}
    case 1n+p k <> kt:
      expanded_rounds_correct(p, C.next_word(history) <> history, kt,
        C.step(s, k, C.next_word(history)))

law schedule_rounds_correct:
  for +ws: List<&2, U32>
  for +extra: Nat
  for +history: List<&2, U32>
  for +ks: List<&2, U32>
  for +s: S.State
  {C.schedule_rounds(ws, extra, history, ks, s) ==
    C.rounds(ks, List.append(&2, U32, ws, C.expand(extra, history)), s) : S.State}

def schedule_rounds_correct(ws, extra, history, ks, s):
  match ws ks:
    case Nil{} _:
      expanded_rounds_correct(extra, history, ks, s)
    case w <> wt Nil{}:
      {==}
    case w <> wt k <> kt:
      schedule_rounds_correct(wt, extra, history, kt, C.step(s, k, w))

law fused_compress_correct:
  for +block: List<&2, U32>
  for +extra: Nat
  for +ks: List<&2, U32>
  for +s: S.State
  {C.fused_compress(block, extra, ks, s) == C.compress(C.schedule(extra, block), ks, s) : S.State}

law fused_compress_slow_correct:
  for +block: List<&2, U32>
  for +extra: Nat
  for +ks: List<&2, U32>
  for +s: S.State
  {C.fused_compress_slow(block, extra, ks, s) == C.compress(C.schedule(extra, block), ks, s) : S.State}

def fused_compress_slow_correct(block, extra, ks, s):
  Equal.cong(S.State, S.State, r => C.feedforward(s, r),
    C.schedule_rounds(block, extra, List.reverse(&2, U32, block), ks, s),
    C.rounds(ks, List.append(&2, U32, block,
      C.expand(extra, List.reverse(&2, U32, block))), s),
    schedule_rounds_correct(block, extra, List.reverse(&2, U32, block), ks, s))

law window_rounds_correct:
  for +q: Nat
  for +a: U32
  for +b: U32
  for +c: U32
  for +d: U32
  for +e: U32
  for +f: U32
  for +g: U32
  for +h: U32
  for +i: U32
  for +j: U32
  for +k: U32
  for +l: U32
  for +m: U32
  for +n: U32
  for +o: U32
  for +p: U32
  for +rest: List<&2, U32>
  for +ks: List<&2, U32>
  for +s: S.State
  {C.window_rounds(q, C.W{a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p}, ks, s) ==
    C.expanded_rounds(q, a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> rest, ks, s) : S.State}

def window_rounds_correct(q, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, rest, ks, s):
  match q ks:
    case 0n Nil{}:
      {==}
    case 0n x <> xt:
      {==}
    case 1n+r Nil{}:
      {==}
    case 1n+r x <> xt:
      window_rounds_correct(r,
        (C.small1(b) + g + C.small0(o) + p : U32),
        a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p <> rest, xt,
        C.step(s, x, (C.small1(b) + g + C.small0(o) + p : U32)))

law window_schedule_rounds_correct:
  for +ws: List<&2, U32>
  for +extra: Nat
  for +a: U32
  for +b: U32
  for +c: U32
  for +d: U32
  for +e: U32
  for +f: U32
  for +g: U32
  for +h: U32
  for +i: U32
  for +j: U32
  for +k: U32
  for +l: U32
  for +m: U32
  for +n: U32
  for +o: U32
  for +p: U32
  for +rest: List<&2, U32>
  for +ks: List<&2, U32>
  for +s: S.State
  {C.window_schedule_rounds(ws, extra, C.W{a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p}, ks, s) ==
    C.schedule_rounds(ws, extra, a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> rest, ks, s) : S.State}

def window_schedule_rounds_correct(ws, extra, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, rest, ks, s):
  match ws ks:
    case Nil{} _:
      window_rounds_correct(extra, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, rest, ks, s)
    case w <> wt Nil{}:
      {==}
    case w <> wt x <> xt:
      window_schedule_rounds_correct(wt, extra, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p,
        rest, xt, C.step(s, x, w))

def fused_compress_correct(block, extra, ks, s):
  match block:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> Nil{}:
      Equal.trans(S.State,
        C.feedforward(s, C.window_schedule_rounds(
          [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra,
          C.W{p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a}, ks, s)),
        C.feedforward(s, C.schedule_rounds(
          [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra,
          [p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a], ks, s)),
        C.feedforward(s, C.rounds(ks, List.append(&2, U32,
          [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p],
          C.expand(extra, [p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a])), s)),
        Equal.cong(S.State, S.State, r => C.feedforward(s, r),
          C.window_schedule_rounds(
            [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra,
            C.W{p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a}, ks, s),
          C.schedule_rounds(
            [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra,
            [p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a], ks, s),
          window_schedule_rounds_correct(
            [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra,
            p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a, Nil{}, ks, s)),
        Equal.cong(S.State, S.State, r => C.feedforward(s, r),
          C.schedule_rounds(
            [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra,
            [p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a], ks, s),
          C.rounds(ks, List.append(&2, U32,
            [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p],
            C.expand(extra, [p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a])), s),
          schedule_rounds_correct(
            [a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra,
            [p, o, n, m, l, k, j, i, h, g, f, e, d, c, b, a], ks, s)))
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> q <> rest:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> q <> rest, extra, ks, s)
    case Nil{}:
      fused_compress_slow_correct(Nil{}, extra, ks, s)
    case a <> Nil{}:
      fused_compress_slow_correct(a <> Nil{}, extra, ks, s)
    case a <> b <> Nil{}:
      fused_compress_slow_correct(a <> b <> Nil{}, extra, ks, s)
    case a <> b <> c <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> h <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> i <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> Nil{}, extra, ks, s)
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> Nil{}:
      fused_compress_slow_correct(a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> Nil{}, extra, ks, s)

law window_compress16_correct:
  for +a: U32
  for +b: U32
  for +c: U32
  for +d: U32
  for +e: U32
  for +f: U32
  for +g: U32
  for +h: U32
  for +i: U32
  for +j: U32
  for +k: U32
  for +l: U32
  for +m: U32
  for +n: U32
  for +o: U32
  for +p: U32
  for +extra: Nat
  for +ks: List<&2, U32>
  for +s: S.State
  {C.window_compress16(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, extra, ks, s) ==
    C.fused_compress([a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p], extra, ks, s) : S.State}

def window_compress16_correct(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, extra, ks, s):
  match ks:
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> k8 <> k9 <> k10 <> k11 <> k12 <> k13 <> k14 <> k15 <> kt:
      {==}
    case Nil{}:
      {==}
    case k0 <> Nil{}:
      {==}
    case k0 <> k1 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> k8 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> k8 <> k9 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> k8 <> k9 <> k10 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> k8 <> k9 <> k10 <> k11 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> k8 <> k9 <> k10 <> k11 <> k12 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> k8 <> k9 <> k10 <> k11 <> k12 <> k13 <> Nil{}:
      {==}
    case k0 <> k1 <> k2 <> k3 <> k4 <> k5 <> k6 <> k7 <> k8 <> k9 <> k10 <> k11 <> k12 <> k13 <> k14 <> Nil{}:
      {==}

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

law block_words_correct:
  for +ws: List<&2, U32>
  for +extra: Nat
  for +ks: List<&2, U32>
  for +s: S.State
  {C.block_words(ws, extra, ks, s) == F.blocks(F.schedules(ws, extra), ks)(s) : S.State}

def block_words_correct(ws, extra, ks, s):
  match ws:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> rest:
      +block = {[a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p] : List<&2, U32>}
      %schedule_correct(extra, block) :
        {C.block_words(rest, extra, ks, C.compress(C.schedule(extra, block), ks, s)) == F.blocks(F.schedules(rest, extra), ks)(F.compress(_, ks, s)) : S.State}
      %compression_correct(C.schedule(extra, block), ks, s) :
        {C.block_words(rest, extra, ks, C.compress(C.schedule(extra, block), ks, s)) == F.blocks(F.schedules(rest, extra), ks)(_) : S.State}
      block_words_correct(rest, extra, ks, C.compress(C.schedule(extra, block), ks, s))
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

law block_bytes_correct:
  for +bytes: List<&2, U32>
  for +extra: Nat
  for +ks: List<&2, U32>
  for +s: S.State
  {C.block_bytes(bytes, extra, ks, s) == F.blocks(F.schedules(F.words(bytes), extra), ks)(s) : S.State}

def block_bytes_correct(bytes, extra, ks, s):
  match bytes:
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> b57 <> b58 <> b59 <> b60 <> b61 <> b62 <> b63 <> rest:
      +block = {[
        C.pack(b0, b1, b2, b3), C.pack(b4, b5, b6, b7), C.pack(b8, b9, b10, b11), C.pack(b12, b13, b14, b15),
        C.pack(b16, b17, b18, b19), C.pack(b20, b21, b22, b23), C.pack(b24, b25, b26, b27), C.pack(b28, b29, b30, b31),
        C.pack(b32, b33, b34, b35), C.pack(b36, b37, b38, b39), C.pack(b40, b41, b42, b43), C.pack(b44, b45, b46, b47),
        C.pack(b48, b49, b50, b51), C.pack(b52, b53, b54, b55), C.pack(b56, b57, b58, b59), C.pack(b60, b61, b62, b63)
      ] : List<&2, U32>}
      +fast = C.window_compress16(
        C.pack(b0, b1, b2, b3), C.pack(b4, b5, b6, b7), C.pack(b8, b9, b10, b11), C.pack(b12, b13, b14, b15),
        C.pack(b16, b17, b18, b19), C.pack(b20, b21, b22, b23), C.pack(b24, b25, b26, b27), C.pack(b28, b29, b30, b31),
        C.pack(b32, b33, b34, b35), C.pack(b36, b37, b38, b39), C.pack(b40, b41, b42, b43), C.pack(b44, b45, b46, b47),
        C.pack(b48, b49, b50, b51), C.pack(b52, b53, b54, b55), C.pack(b56, b57, b58, b59), C.pack(b60, b61, b62, b63),
        extra, ks, s)
      %schedule_correct(extra, block) :
        {C.block_bytes(rest, extra, ks, fast) == F.blocks(F.schedules(F.words(rest), extra), ks)(F.compress(_, ks, s)) : S.State}
      %compression_correct(C.schedule(extra, block), ks, s) :
        {C.block_bytes(rest, extra, ks, fast) == F.blocks(F.schedules(F.words(rest), extra), ks)(_) : S.State}
      %fused_compress_correct(block, extra, ks, s) :
        {C.block_bytes(rest, extra, ks, fast) == F.blocks(F.schedules(F.words(rest), extra), ks)(_) : S.State}
      %window_compress16_correct(
        C.pack(b0, b1, b2, b3), C.pack(b4, b5, b6, b7), C.pack(b8, b9, b10, b11), C.pack(b12, b13, b14, b15),
        C.pack(b16, b17, b18, b19), C.pack(b20, b21, b22, b23), C.pack(b24, b25, b26, b27), C.pack(b28, b29, b30, b31),
        C.pack(b32, b33, b34, b35), C.pack(b36, b37, b38, b39), C.pack(b40, b41, b42, b43), C.pack(b44, b45, b46, b47),
        C.pack(b48, b49, b50, b51), C.pack(b52, b53, b54, b55), C.pack(b56, b57, b58, b59), C.pack(b60, b61, b62, b63),
        extra, ks, s) :
        {C.block_bytes(rest, extra, ks, fast) == F.blocks(F.schedules(F.words(rest), extra), ks)(_) : S.State}
      block_bytes_correct(rest, extra, ks, fast)
    case Nil{}:
      {==}
    case b0 <> Nil{}:
      {==}
    case b0 <> b1 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> b57 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> b57 <> b58 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> b57 <> b58 <> b59 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> b57 <> b58 <> b59 <> b60 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> b57 <> b58 <> b59 <> b60 <> b61 <> Nil{}:
      {==}
    case b0 <> b1 <> b2 <> b3 <> b4 <> b5 <> b6 <> b7 <> b8 <> b9 <> b10 <> b11 <> b12 <> b13 <> b14 <> b15 <> b16 <> b17 <> b18 <> b19 <> b20 <> b21 <> b22 <> b23 <> b24 <> b25 <> b26 <> b27 <> b28 <> b29 <> b30 <> b31 <> b32 <> b33 <> b34 <> b35 <> b36 <> b37 <> b38 <> b39 <> b40 <> b41 <> b42 <> b43 <> b44 <> b45 <> b46 <> b47 <> b48 <> b49 <> b50 <> b51 <> b52 <> b53 <> b54 <> b55 <> b56 <> b57 <> b58 <> b59 <> b60 <> b61 <> b62 <> Nil{}:
      {==}


# Unlike the old theorem, there is NO arbitrary preprocessing parameter.
# This proves the actual implementation pipeline against the independent one.
law hash_correct:
  for +bytes: List<&2, U32>
  for +extra: Nat
  for +ks: List<&2, U32>
  {C.hash(bytes, extra, ks) == F.hash(bytes, extra, ks) : List<&2, U32>}

def hash_correct(bytes, extra, ks):
  %pad_correct(bytes) :
    {C.hash(bytes, extra, ks) == F.digest(F.blocks(F.schedules(F.words(_), extra), ks)(F.initial())) : List<&2, U32>}
  %digest_correct(F.blocks(F.schedules(F.words(C.pad(bytes)), extra), ks)(F.initial())) :
    {C.hash(bytes, extra, ks) == _ : List<&2, U32>}
  Equal.cong(S.State, List<&2, U32>, s => C.digest(s),
    C.block_bytes(C.pad(bytes), extra, ks, C.initial()),
    F.blocks(F.schedules(F.words(C.pad(bytes)), extra), ks)(C.initial()),
    block_bytes_correct(C.pad(bytes), extra, ks, C.initial()))
