package body Files.Jobs.Scavenger.Testing is

   function Busy_Reason return String renames Files.Jobs.Scavenger.Busy_Reason;

   function Was_Reported (Directory : String) return Boolean renames Files.Jobs.Scavenger.Was_Reported;

end Files.Jobs.Scavenger.Testing;
