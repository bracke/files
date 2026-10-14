with Ada.Directories;

with Hostkit.Fs;
with Files.Platform_Regular_Files;

package body Files.Fs is
   use type Ada.Directories.File_Kind;
   use type Hostkit.Fs.Delete_Tree_Outcome;

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

   function Open_Regular_Read
     (Path : String) return GNAT.OS_Lib.File_Descriptor
   is
      Supported : Boolean;
   begin
      for Value of Path loop
         if Value = ASCII.NUL then
            return GNAT.OS_Lib.Invalid_FD;
         end if;
      end loop;
      return Files.Platform_Regular_Files.Open_Read (Path, False, Supported);
   end Open_Regular_Read;

   function Open_Regular_Read_Following_Links
     (Path : String) return GNAT.OS_Lib.File_Descriptor
   is
      Supported : Boolean;
   begin
      for Value of Path loop
         if Value = ASCII.NUL then
            return GNAT.OS_Lib.Invalid_FD;
         end if;
      end loop;
      return Files.Platform_Regular_Files.Open_Read (Path, True, Supported);
   end Open_Regular_Read_Following_Links;

   procedure Delete_Tree (Path : String) is
   begin
      if not Ada.Directories.Exists (Path) and then not Hostkit.Fs.Is_Link (Path) then
         return;
      end if;
      if Hostkit.Fs.Delete_Tree_No_Follow (Path) /= Hostkit.Fs.Tree_Deleted then
         raise Ada.Directories.Use_Error;
      end if;
   end Delete_Tree;

end Files.Fs;
