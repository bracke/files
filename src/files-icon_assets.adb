with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

with Files.Capped_Files;
with Files.Resources;
with Guikit.Draw;

package body Files.Icon_Assets is

   package Text_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => String,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Cache : Text_Maps.Map;
   Max_Icon_Asset_Bytes : constant := 64 * 1024;

   function Valid_Icon_Id (Value : String) return Boolean is
   begin
      if Value'Length not in 1 .. 64 then
         return False;
      end if;

      for Item of Value loop
         if Item not in 'a' .. 'z' | '0' .. '9' | '-' | '_' then
            return False;
         end if;
      end loop;
      return True;
   end Valid_Icon_Id;

   function Valid_Theme_Name (Value : String) return Boolean is
     (Value in "" | "files-basic" | "files-high-contrast");

   function Icons_Root return String is
     (Files.Resources.Share_Path ("files/icons"));

   --  Read one small icon definition byte-for-byte. Returns "" on any error
   --  and for a definition larger than Max_Icon_Asset_Bytes.
   function Read_File (Path : String) return String is
      use type Files.Capped_Files.Read_Status;

      Status : Files.Capped_Files.Read_Status;
      Text   : constant String :=
        Files.Capped_Files.Read_Capped
          (Path, Max_Icon_Asset_Bytes, Files.Capped_Files.Follow_Links, Status);
   begin
      return (if Status = Files.Capped_Files.Read_Complete then Text else "");
   end Read_File;

   function Disk_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String
   is
   begin
      if not Valid_Icon_Id (Icon_Id) or else not Valid_Theme_Name (Theme_Name) then
         return "";
      end if;

      declare
         Key  : constant String := Theme_Name & "|" & Icon_Id;
         Root : constant String := Icons_Root;
         Sub  : constant String :=
           (if Theme_Name = "files-high-contrast" then "/high-contrast" else "");
         Path : constant String := Root & Sub & "/" & Icon_Id & ".icon";
      begin
         if Root = "" then
            return "";
         end if;
         if Cache.Contains (Key) then
            return Cache.Element (Key);
         end if;

         declare
            Text : constant String := Read_File (Path);
         begin
            Cache.Insert (Key, Text);
            return Text;
         end;
      end;
   end Disk_Icon_Asset;

   procedure Register is
   begin
      Guikit.Draw.Set_Icon_Asset_Source (Disk_Icon_Asset'Access);
   end Register;

end Files.Icon_Assets;
