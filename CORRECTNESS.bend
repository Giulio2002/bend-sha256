import Base
import ./sha256.bend as SHA
import ./fips.bend as FIPS
import ./conformance.bend as Conformance
import ./LAWS.bend as Laws

# This gate contains NO concrete-message test vectors.
def Laws.constants_correct():
  {==}

def Laws.sha256_correct(bytes):
  Conformance.hash_correct(bytes, 48n, SHA.constants())
