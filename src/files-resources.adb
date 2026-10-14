with Ada.Directories;
with Ada.Strings.Unbounded;

with Hostkit.Fs;

package body Files.Resources is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;

   function Locate_Share_Root return String is
      Executable_Directory : constant String :=
        Hostkit.Fs.Own_Executable_Directory;

      function Parent (Path : String) return String is
        (Ada.Directories.Containing_Directory (Path));

      function Share_At (Levels : Natural) return String is
         Base : Unbounded_String :=
           To_Unbounded_String (Executable_Directory);
      begin
         for Level in 1 .. Levels loop
            Base := To_Unbounded_String (Parent (To_String (Base)));
         end loop;
         return Ada.Directories.Full_Name
           (Hostkit.Fs.Join (To_String (Base), "share"));
      exception
         when others =>
            return "";
      end Share_At;

      function Complete (Path : String) return Boolean is
         Catalog : constant String := Hostkit.Fs.Join (Path, "files.catalog");
         Icons   : constant String := Hostkit.Fs.Join (Path, "files/icons");
      begin
         return Path /= ""
           and then Ada.Directories.Exists (Catalog)
           and then Ada.Directories.Kind (Catalog) = Ada.Directories.Ordinary_File
           and then Ada.Directories.Exists (Icons)
           and then Ada.Directories.Kind (Icons) = Ada.Directories.Directory;
      exception
         when others =>
            return False;
      end Complete;
   begin
      if Executable_Directory = "" then
         return "";
      end if;

      for Levels in 0 .. 2 loop
         declare
            Candidate : constant String := Share_At (Levels);
         begin
            if Complete (Candidate) then
               return Candidate;
            end if;
         end;
      end loop;

      --  Keep failure anchored beside the executable. A relative fallback
      --  would let the launch directory provide counterfeit resources.
      return Share_At (1);
   exception
      when others =>
         return "";
   end Locate_Share_Root;

   Located_Share_Root : constant String := Locate_Share_Root;

   function Share_Root return String is (Located_Share_Root);

   function Share_Path (Relative_Path : String) return String is
     (if Located_Share_Root = "" then ""
      else Hostkit.Fs.Join (Located_Share_Root, Relative_Path));

end Files.Resources;
