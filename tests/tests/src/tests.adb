with Ada.Command_Line;
with Ada.Environment_Variables;

with AUnit;
with AUnit.Reporter.Text;
with AUnit.Run;
with All_Suites;

procedure Tests is
   use type AUnit.Status;

   function Run is new AUnit.Run.Test_Runner_With_Status (All_Suites.Suite);

   Reporter : AUnit.Reporter.Text.Text_Reporter;
   Status   : AUnit.Status;
begin
   --  Pin the locale so localization-dependent assertions are deterministic
   --  regardless of the developer machine's locale (C normalizes to "en").
   Ada.Environment_Variables.Set ("LC_ALL", "C");
   Status := Run (Reporter);
   if Status = AUnit.Failure then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
