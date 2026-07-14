package body Files.Platform.Process is

   --  Nothing here launches anything, so there is nothing to collect and no command
   --  line to run.
   procedure Reap_Finished_Children is
   begin
      null;
   end Reap_Finished_Children;

   function Supports_Raw_Command_Line return Boolean is
   begin
      return False;
   end Supports_Raw_Command_Line;

   function Run_Command_Line
     (Command     : String;
      Wait        : Boolean;
      Exit_Status : out Integer)
      return Boolean
   is
      pragma Unreferenced (Command, Wait);
   begin
      Exit_Status := -1;
      return False;
   end Run_Command_Line;

end Files.Platform.Process;
