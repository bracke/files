with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Directories;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Guikit.Draw;

package body Files.Icon_Assets is

   use Ada.Strings.Unbounded;

   package Text_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Cache : Text_Maps.Map;

   --  Locate the bundled icon directory the same way the catalog is located:
   --  relative to the current directory, then one or two levels up (covering the
   --  in-tree bin/ and obj build layouts).
   function Icons_Root return String is
   begin
      if Ada.Directories.Exists ("share/files/icons") then
         return "share/files/icons";
      elsif Ada.Directories.Exists ("../../share/files/icons") then
         return "../../share/files/icons";
      elsif Ada.Directories.Exists ("../share/files/icons") then
         return "../share/files/icons";
      end if;
      return "share/files/icons";
   end Icons_Root;

   --  Read a whole text file, joining its lines with LF (the parser trims each
   --  line, so exact line terminators do not matter). Returns "" on any error.
   function Read_File (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Result : Unbounded_String;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Append (Result, Ada.Text_IO.Get_Line (File));
         Append (Result, ASCII.LF);
      end loop;
      Ada.Text_IO.Close (File);
      return To_String (Result);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end Read_File;

   function Disk_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String
   is
      Key : constant String := Theme_Name & "|" & Icon_Id;
   begin
      if Cache.Contains (Key) then
         return Cache.Element (Key);
      end if;

      declare
         Sub  : constant String :=
           (if Theme_Name = "files-high-contrast" then "/high-contrast" else "");
         Path : constant String := Icons_Root & Sub & "/" & Icon_Id & ".icon";
         Text : constant String := Read_File (Path);
      begin
         Cache.Insert (Key, Text);
         return Text;
      end;
   end Disk_Icon_Asset;

   procedure Register is
   begin
      Guikit.Draw.Set_Icon_Asset_Source (Disk_Icon_Asset'Access);
   end Register;

end Files.Icon_Assets;
