# bend-sha256: pure Bend SHA-256 with packed arrays and checked source proofs.
# Source: https://github.com/Giulio2002/bend-sha256
# Based on release c77b76cc084ddd5aa1c930ac8215b2f3d148afc0, Bend 2.0.16.
#
# Input: four big-endian bytes per U32 plus the logical byte length.
# Output: Some{eight big-endian U32 words}, exactly 32 digest bytes;
# None if byte_length exceeds the input array's capacity in bytes.
# Unused trailing input bytes/slots are ignored. Input is consumed.
# No crypto FFI, hardware intrinsics, or runtime linked-list representation.
#
# Proof scope: universal refinement of the public array API to the independent
# packed-input specification, with digest word-order and size laws. Historical
# byte-list models are also proved against the independent FIPS specification.
# The universal bridge from packed bytes to that original byte-list theorem is
# not claimed. The Bend kernel, Base, compiler, C toolchain and CPU are trusted.
# Full scope: https://github.com/Giulio2002/bend-sha256/blob/main/CORRECTNESS.md
#
# This entry checks and bundles the proofs. For implementation-only imports,
# use sha256.bend from the same content-addressed package.
import Base
import ./sha256.bend as SHA
import ./PROOF.bend as Proof

def sha256(words: Array<U32>, byte_length: Nat) -> Maybe<&1,Array<U32>>:
  SHA.sha256(words,byte_length)

def hex(digest: Array<U32>) -> String:
  SHA.hex(digest)
