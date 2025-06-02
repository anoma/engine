[
  # Add any dialyzer warnings to ignore here if needed
  # Example:
  # ~r"lib/some_module.ex:123:pattern_match"

  # Ignore warnings for mailbox update function - this code is future-proofing
  # for when mailbox engines (mode: :mailbox) are actually used in the system
  ~r"lib/engine_system/system/spawner.ex:362:contract_supertype",
  ~r"lib/engine_system/system/spawner.ex:363:.*:pattern_match"
]
