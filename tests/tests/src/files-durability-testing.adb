with Ada.Environment_Variables;
with Ada.Strings.Unbounded;

package body Files.Durability.Testing is
   use Ada.Strings.Unbounded;

   --  What is armed, so arming one fault keeps the other.
   Failing_Suffix : Unbounded_String;
   Failing_Stage  : Boolean := False;

   procedure Fail_Syncs_Ending_With (Suffix : String) is
   begin
      Failing_Suffix := To_Unbounded_String (Suffix);
      Set_Faults (Suffix, Failing_Stage);
   end Fail_Syncs_Ending_With;

   procedure Fail_Stage_Sync is
   begin
      Failing_Stage := True;
      Set_Faults (To_String (Failing_Suffix), Stage => True);
   end Fail_Stage_Sync;

   procedure Clear is
   begin
      Failing_Suffix := Null_Unbounded_String;
      Failing_Stage := False;
      Set_Faults ("", Stage => False);
   end Clear;

   procedure Install_From_Environment is
      Suffix : constant String := Ada.Environment_Variables.Value ("FILES_TEST_SYNC_FAULT_SUFFIX", "");
   begin
      if Suffix /= "" then
         Fail_Syncs_Ending_With (Suffix);
      end if;
      if Ada.Environment_Variables.Value ("FILES_TEST_STAGE_SYNC_FAULT", "") /= "" then
         Fail_Stage_Sync;
      end if;
   end Install_From_Environment;

end Files.Durability.Testing;
