with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Files_Suite.Support.Processes is

   --  The fields of /proc/<pid>/stat after "pid (comm) ", from the state
   --  on, or "" when there is no such process: comm may itself hold spaces
   --  and parentheses, so they follow the last ')'.
   function Stat_Fields (Process_Id : Integer) return String is
      Path : constant String :=
        "/proc/" & Ada.Strings.Fixed.Trim (Integer'Image (Process_Id), Ada.Strings.Both) & "/stat";
      File : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;
      --  Text_IO, not a sized read: /proc files report a size of 0.
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Close (File);
         return "";
      end if;
      declare
         Line : constant String := Ada.Text_IO.Get_Line (File);
         Close_Paren : constant Natural := Ada.Strings.Fixed.Index (Line, ")", Ada.Strings.Backward);
      begin
         Ada.Text_IO.Close (File);
         return (if Close_Paren > 0 and then Close_Paren + 2 <= Line'Last then Line (Close_Paren + 2 .. Line'Last)
                 else "");
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Stat_Fields;

   function Process_State (Process_Id : Integer) return Character is
      Fields : constant String := Stat_Fields (Process_Id);
   begin
      return (if Fields = "" then ' ' else Fields (Fields'First));
   end Process_State;

   function Start_Time (Process_Id : Integer) return String is
      Fields : constant String := Stat_Fields (Process_Id);
      --  The state is the stat's third field; the start time its 22nd.
      Field  : Positive := 3;
      First  : Positive := Fields'First;
   begin
      for Index in Fields'Range loop
         if Fields (Index) = ' ' then
            if Field = 22 then
               return Fields (First .. Index - 1);
            end if;
            Field := Field + 1;
            First := Index + 1;
         end if;
      end loop;
      return (if Field = 22 and then First <= Fields'Last then Fields (First .. Fields'Last) else "");
   end Start_Time;

   function Process_State (Process_Id : Integer; Started : String) return Character is
     (if Started /= "" and then Start_Time (Process_Id) = Started then Process_State (Process_Id) else ' ');

end Files_Suite.Support.Processes;
