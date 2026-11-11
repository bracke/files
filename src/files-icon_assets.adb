with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

with Files.Capped_Files;
with Files.Icon_Themes;
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
     (Value = "" or else Files.Icon_Themes.Is_Name (Value));

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
           (if Theme_Name = "" then "" else Files.Icon_Themes.Subdirectory (Files.Icon_Themes.Value (Theme_Name)));
         Path : constant String := Root & Sub & "/" & Icon_Id & ".icon";
      begin
         if Root = "" then
            return "";
         end if;
         declare
            Position : constant Text_Maps.Cursor := Cache.Find (Key);
         begin
            if Text_Maps.Has_Element (Position) then
               return Text_Maps.Element (Position);
            end if;
         end;

         declare
            Text : constant String := Read_File (Path);
         begin
            Cache.Insert (Key, Text);
            return Text;
         end;
      end;
   end Disk_Icon_Asset;

   function Builtin_Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String
   is
      use type Files.Icon_Themes.Icon_Theme;

      LF : constant String := [1 => ASCII.LF];

      --  A page's folded corner: the border colour in a high-contrast theme.
      Corner_Role : constant String :=
        (if Theme_Name /= "" and then Files.Icon_Themes.Value (Theme_Name) = Files.Icon_Themes.High_Contrast
         then "border"
         else "muted");

      --  One line of the definition.
      function L (Line : String) return String is (Line & LF);

      function Header (Grid : String) return String is
        (L ("files-icon-v1") & L ("name=" & Icon_Id) & L ("grid=" & Grid));

      --  A page on the 32-unit grid with a folded top-right corner (a
      --  triangle). The filetype's glyph is painted over it.
      function Document (Glyph : String) return String is
        (Header ("32")
         & L ("rect=5,0,13,32,base")
         & L ("rect=18,7,9,25,base")
         & L ("tri=18,0,27,7,18,7," & Corner_Role)
         & Glyph);
   begin
      if not Valid_Icon_Id (Icon_Id) or else not Valid_Theme_Name (Theme_Name) then
         return "";
      elsif Icon_Id = "folder" then
         return Header ("32")
           & L ("rect=0,1,13,8,base")
           & L ("tri=13,1,13,9,19,9,base")
           & L ("rect=0,9,32,22,base")
           & L ("rect=0,9,32,4,accent")
           & L ("rect=3,16,26,1,border");
      elsif Icon_Id = "text" then
         return Header ("64")
           & L ("rect=10,0,27,64,base")
           & L ("rect=37,15,17,49,base")
           & L ("tri=37,0,54,15,37,15," & Corner_Role)
           & L ("rect=17,25,30,3,border")
           & L ("rect=17,34,30,4,border")
           & L ("rect=17,44,30,4,border")
           & L ("rect=17,54,20,4,border");
      elsif Icon_Id = "image" then
         return Document
           (L ("rect=7,12,18,16,accent")
            & L ("rect=10,15,4,3,base")
            & L ("tri=7,28,16,16,21,28,border")
            & L ("tri=15,28,21,21,25,28,border"));
      elsif Icon_Id = "executable" then
         return Document
           (L ("tri=10,12,10,22,18,17,accent")
            & L ("rect=12,25,10,2,border"));
      elsif Icon_Id = "link" then
         return Document
           (L ("tri=12,25,15,25,22,12,accent")
            & L ("tri=15,25,22,12,22,15,accent")
            & L ("tri=15,10,25,10,25,20,accent"));
      elsif Icon_Id = "unknown" then
         return Document
           (L ("rect=12,11,9,3,border")
            & L ("rect=18,12,3,5,border")
            & L ("rect=15,16,6,2,border")
            & L ("rect=15,18,2,5,border")
            & L ("rect=15,27,2,3,border"));
      elsif Icon_Id = "ada" then
         return Document
           (L ("tri=15,11,17,11,10,30,accent")
            & L ("tri=15,11,10,30,12,30,accent")
            & L ("tri=15,11,17,11,22,30,accent")
            & L ("tri=17,11,22,30,20,30,accent")
            & L ("rect=12,22,8,3,border"));
      elsif Icon_Id = "markdown" then
         return Document
           (L ("rect=9,11,2,11,border")
            & L ("rect=21,11,2,11,border")
            & L ("tri=10,11,22,11,16,18,border")
            & L ("rect=15,22,2,4,accent")
            & L ("tri=12,25,20,25,16,30,accent"));
      elsif Icon_Id = "thumbnail" then
         return Header ("16")
           & L ("rect=1,1,14,14,border")
           & L ("rect=2,2,12,12,base")
           & L ("rect=3,3,10,7,accent")
           & L ("rect=4,8,4,2,border")
           & L ("rect=8,7,4,3,border")
           & L ("rect=3,12,10,1,muted");
      elsif Icon_Id = "toolbar-home" then
         return Header ("16")
           & L ("rect=7,2,2,1,border")
           & L ("rect=6,3,4,1,border")
           & L ("rect=5,4,6,1,border")
           & L ("rect=4,5,8,1,border")
           & L ("rect=3,6,10,2,border")
           & L ("rect=4,8,2,5,border")
           & L ("rect=10,8,2,5,border")
           & L ("rect=6,12,4,1,border")
           & L ("rect=7,9,2,4,border");
      elsif Icon_Id = "toolbar-back" then
         return Header ("16")
           & L ("rect=7,3,2,2,border")
           & L ("rect=6,5,2,2,border")
           & L ("rect=4,7,8,2,border")
           & L ("rect=6,9,2,2,border")
           & L ("rect=7,11,2,2,border");
      elsif Icon_Id = "toolbar-forward" then
         return Header ("16")
           & L ("rect=7,3,2,2,border")
           & L ("rect=8,5,2,2,border")
           & L ("rect=4,7,8,2,border")
           & L ("rect=8,9,2,2,border")
           & L ("rect=7,11,2,2,border");
      elsif Icon_Id = "toolbar-parent" then
         return Header ("16")
           & L ("rect=7,3,2,2,border")
           & L ("rect=5,5,2,2,border")
           & L ("rect=9,5,2,2,border")
           & L ("rect=7,7,2,6,border")
           & L ("rect=3,7,2,2,border")
           & L ("rect=11,7,2,2,border");
      elsif Icon_Id = "toolbar-create" then
         return Header ("16")
           & L ("rect=7,3,2,10,border")
           & L ("rect=3,7,10,2,border");
      elsif Icon_Id = "toolbar-delete" then
         return Header ("16")
           & L ("rect=6,3,4,1,border")
           & L ("rect=4,5,8,2,border")
           & L ("rect=5,7,1,6,border")
           & L ("rect=10,7,1,6,border")
           & L ("rect=5,12,6,1,border")
           & L ("rect=7,8,1,4,border")
           & L ("rect=9,8,1,4,border");
      else
         return "";
      end if;
   end Builtin_Icon_Asset;

   --  The definition chosen per theme and icon, so a frame neither re-reads
   --  nor re-parses a file to decide between it and the compiled-in copy.
   Chosen : Text_Maps.Map;

   function Icon_Asset
     (Icon_Id    : String;
      Theme_Name : String)
      return String
   is
   begin
      if not Valid_Icon_Id (Icon_Id) or else not Valid_Theme_Name (Theme_Name) then
         return "";
      end if;

      declare
         Key      : constant String := Theme_Name & "|" & Icon_Id;
         Position : constant Text_Maps.Cursor := Chosen.Find (Key);
      begin
         if Text_Maps.Has_Element (Position) then
            return Text_Maps.Element (Position);
         end if;

         declare
            Disk : constant String := Disk_Icon_Asset (Icon_Id, Theme_Name);
            Text : constant String :=
              (if Disk /= "" and then Guikit.Draw.Parse_Icon_Asset (Disk).Valid
               then Disk
               else Builtin_Icon_Asset (Icon_Id, Theme_Name));
         begin
            Chosen.Insert (Key, Text);
            return Text;
         end;
      end;
   end Icon_Asset;

   procedure Register is
   begin
      Guikit.Draw.Set_Icon_Asset_Source (Icon_Asset'Access);
   end Register;

begin
   Register;
end Files.Icon_Assets;
