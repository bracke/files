with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Files_Suite.Support.Processes is

   function Process_State (Process_Id : Integer) return Character is
      Path : constant String :=
        "/proc/" & Ada.Strings.Fixed.Trim (Integer'Image (Process_Id), Ada.Strings.Both) & "/stat";
      File : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return ' ';
      end if;
      --  Text_IO, not a sized read: /proc files report a size of 0.
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Close (File);
         return ' ';
      end if;
      declare
         Line : constant String := Ada.Text_IO.Get_Line (File);
         --  "pid (comm) state ...": comm may itself hold spaces and
         --  parentheses, so the state follows the last ')'.
         Close_Paren : constant Natural := Ada.Strings.Fixed.Index (Line, ")", Ada.Strings.Backward);
      begin
         Ada.Text_IO.Close (File);
         return (if Close_Paren > 0 and then Close_Paren + 2 <= Line'Last then Line (Close_Paren + 2) else ' ');
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return ' ';
   end Process_State;

end Files_Suite.Support.Processes;
