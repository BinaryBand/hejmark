import Lake
open Lake DSL

package «L1» where

-- Pinned to the mathlib4 revision building against Lean 4.32.0 (the toolchain
-- pinned in lean-toolchain), so a bump of one must come with a bump of the
-- other.
require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "11d11a11a667a8fa8ea19d9456fe059f683e308f"

@[default_target]
lean_lib «L1» where
