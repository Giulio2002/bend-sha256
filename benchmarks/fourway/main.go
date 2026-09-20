package main

import (
    "crypto/sha256"
    "fmt"
    "os"
    "strconv"
    "time"
)

func main() {
    size, err := strconv.Atoi(os.Getenv("SHA_BENCH_SIZE"))
    if err != nil || size < 1 { panic("invalid message size") }
    corpus, err := os.ReadFile(os.Getenv("SHA_BENCH_INPUT"))
    if err != nil { panic(err) }
    if len(corpus)%size != 0 { panic("non-integral batch") }
    inputs := make([][]byte, len(corpus)/size)
    for i := range inputs { inputs[i] = corpus[i*size:(i+1)*size] }
    start := time.Now()
    outputs := make([][32]byte, len(inputs))
    for i, input := range inputs { outputs[i] = sha256.Sum256(input) }
    elapsed := time.Since(start)
    fmt.Printf("BENCH_MS=%.6f\n", float64(elapsed.Nanoseconds())/1e6)
    for i := len(outputs)-1; i >= 0; i-- { fmt.Printf("%x\n", outputs[i]) }
}
