with Ada.Command_Line;

procedure Failing is
begin
   --  The counterpart to Noop: a real executable that fails, for the tests that
   --  check a non-zero exit is not surfaced to the user.
   Ada.Command_Line.Set_Exit_Status (1);
end Failing;
