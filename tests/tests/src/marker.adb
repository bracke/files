with Ada.Command_Line;
with Ada.Text_IO;

procedure Marker is
   --  A program that records the fact that it ran, by creating the file named as
   --  its first argument.
   --
   --  The preflight tests need to prove that a *failed* preflight ran nothing at
   --  all -- not merely that the result says so. That needs an action whose
   --  execution leaves a trace. It used to be "/bin/sh -c touch <path>", which is
   --  two POSIX assumptions: on Windows there is no /bin/sh, so the action failed
   --  on its missing executable long before reaching the item the test was
   --  actually about, and the test asserted the wrong failure for the wrong reason.
   File : Ada.Text_IO.File_Type;
begin
   if Ada.Command_Line.Argument_Count < 1 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Ada.Command_Line.Argument (1));
   Ada.Text_IO.Close (File);
end Marker;
