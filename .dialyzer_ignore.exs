[
  # Add any dialyzer warnings to ignore here if needed
  # Example:
  # ~r"lib/some_module.ex:123:pattern_match"

  # Ignore warnings for mailbox update function - this code is future-proofing
  # for when mailbox engines (mode: :mailbox) are actually used in the system
  ~r"lib/engine_system/system/spawner.ex:362:contract_supertype",
  ~r"lib/engine_system/system/spawner.ex:363:.*:pattern_match",
  
  # Ignore pattern match warning in DiagramGenerator - unreachable code but kept for completeness
  ~r"lib/engine_system/engine/diagram_generator.ex:1065:pattern_match_cov",
  
  # Ignore guard and pattern warnings in DSLMailboxSimple example - example code with intentional patterns
  ~r"lib/examples/dsl_mailbox_simple.ex:175:guard_fail",
  ~r"lib/examples/dsl_mailbox_simple.ex:175:pattern_match",
]
