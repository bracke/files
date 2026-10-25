--  Assert_Equal for any discrete type (statuses, command ids, modes), so a
--  failing comparison says both values. Files_Suite.Support instantiates it
--  for the types the suite compares most.
generic
   type Value is (<>);
--  Assert Actual = Expected; a failure says both values.
--
--  @param Actual Observed value.
--  @param Expected Wanted value.
--  @param Message What the check is about.
procedure Files_Suite.Generic_Assert_Equal (Actual, Expected : Value; Message : String);
