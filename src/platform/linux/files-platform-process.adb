with System;
with Interfaces.C;

package body Files.Platform.Process is

   use type Interfaces.C.int;

   WNOHANG : constant Interfaces.C.int := 1;

   --  Any child, do not block: waitpid (-1, NULL, WNOHANG). It returns the pid of
   --  a collected child, 0 when children exist but none have finished, and -1 when
   --  there are none at all -- so a bounded loop drains what is ready and stops.
   function Waitpid
     (Pid     : Interfaces.C.int;
      Status  : System.Address;
      Options : Interfaces.C.int)
      return Interfaces.C.int
     with Import => True, Convention => C, External_Name => "waitpid";

   procedure Reap_Finished_Children is
      Collected : Interfaces.C.int;
   begin
      loop
         Collected := Waitpid (-1, System.Null_Address, WNOHANG);
         exit when Collected <= 0;
      end loop;
   exception
      when others =>
         null;
   end Reap_Finished_Children;

   --  POSIX needs no raw command line: sh takes "-c" and the command as ordinary
   --  vector elements, and nothing rewrites them on the way.
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
