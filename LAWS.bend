import Base
import ./sha256.bend as SHA
import ./fips.bend as FIPS

# These claims mention the actual public API and the complete independent spec.
# There are no arbitrary preprocessing functions, tables, or correctness premises.
law constants_correct:
  {SHA.constants() == FIPS.constants() : List<&2, U32>}

law sha256_correct:
  for +bytes: List<&2, U32>
  {SHA.sha256(bytes) == FIPS.sha256(bytes) : List<&2, U32>}
