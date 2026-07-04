with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Text_IO;

package body Files.Fs is
   use type Ada.Directories.File_Kind;

   function Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   end Exists;

   function File_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File;
   exception
      when others =>
         return False;
   end File_Exists;

   function Directory_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Directory;
   exception
      when others =>
         return False;
   end Directory_Exists;

   procedure Delete_Tree (Path : String) is
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Tree (Path);
      end if;
   end Delete_Tree;

   function Read_Text_File (Path : String) return Ada.Strings.Unbounded.Unbounded_String is
      use Ada.Strings.Unbounded;
      File   : Ada.Text_IO.File_Type;
      Result : Unbounded_String := Null_Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Append (Result, Ada.Text_IO.Get_Line (File));
         Append (Result, Ada.Characters.Latin_1.LF);
      end loop;
      Ada.Text_IO.Close (File);
      return Result;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return Null_Unbounded_String;
   end Read_Text_File;

end Files.Fs;
