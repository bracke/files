with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Guikit.Utf8.Editing;
with Files.Name_Parts;
with Files.Text_Basics;
with Files.Text_Case;

package body Files.File_Types is

   function Trim_Name (Name : String) return String is
      First_Offset      : Natural := 0;
      Last_Content_Last : Natural := 0;
   begin
      if Name = "" then
         return "";
      end if;

      while First_Offset < Name'Length loop
         declare
            Separator_Length : constant Natural := Guikit.Utf8.Whitespace_Separator_Length (Name, First_Offset);
         begin
            exit when Separator_Length = 0;
            First_Offset := First_Offset + Separator_Length;
         end;
      end loop;

      if First_Offset >= Name'Length then
         return "";
      end if;

      declare
         Position : Natural := First_Offset;
      begin
         while Position < Name'Length loop
            declare
               Separator_Length : constant Natural := Guikit.Utf8.Whitespace_Separator_Length (Name, Position);
               Next_Position    : Natural := Position;
            begin
               if Separator_Length > 0 then
                  Next_Position := Position + Separator_Length;
               else
                  Next_Position := Guikit.Utf8.Editing.Next_Boundary (Name, Position);
                  if Next_Position <= Position then
                     Next_Position := Position + 1;
                  end if;
                  Last_Content_Last := Name'First + Next_Position - 1;
               end if;

               Position := Next_Position;
            end;
         end loop;
      end;

      if Last_Content_Last < Name'First + First_Offset then
         return "";
      end if;

      return Name (Name'First + First_Offset .. Last_Content_Last);
   end Trim_Name;

   --  The last component of Name, blanks around it trimmed: a path's
   --  trailing separators are dropped (Files.Name_Parts.Leaf_Of), as everywhere
   --  else a leaf is taken.
   function Leaf_Name (Name : String) return String is (Files.Name_Parts.Leaf_Of (Trim_Name (Name)));

   function Normalize_Extension (Extension : String) return String is
      Clean : constant String := Files.Text_Basics.Trim_Blanks (Extension);
   begin
      if Clean = "" then
         return "";
      elsif Clean (Clean'First) = '.' then
         if Clean'Length = 1 then
            return "";
         end if;
         return Files.Text_Case.To_Lower_Unicode
           (Files.Text_Basics.Trim_Blanks (Clean (Clean'First + 1 .. Clean'Last)));
      else
         return Files.Text_Case.To_Lower_Unicode (Clean);
      end if;
   end Normalize_Extension;

   function Filetype_For_Extension
     (Mapping   : String_Maps.Map;
      Extension : String)
      return String
   is
      Position : constant String_Maps.Cursor := Mapping.Find (Normalize_Extension (Extension));
   begin
      return (if String_Maps.Has_Element (Position) then String_Maps.Element (Position) else "");
   end Filetype_For_Extension;

   function Icon_For_Filetype
     (Mapping  : String_Maps.Map;
      Filetype : String)
      return String
   is
      Position : constant String_Maps.Cursor := Mapping.Find (Files.Text_Basics.Trim_Blanks (Filetype));
   begin
      return (if String_Maps.Has_Element (Position) then String_Maps.Element (Position) else "");
   end Icon_For_Filetype;

   function Default_Classification return Classification is
      Result : Classification;

      procedure Extension (Name, Filetype : String) is
      begin
         Result.Extension_Filetypes.Include (Normalize_Extension (Name), Filetype);
      end Extension;

      procedure Icon (Filetype, Icon_Id : String) is
      begin
         Result.Icon_Mappings.Include (Filetype, Icon_Id);
      end Icon;

      Word_Document : constant String := "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
      Spreadsheet   : constant String := "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
   begin
      Extension ("txt", "text/plain");
      Extension ("adb", "text/x-ada");
      Extension ("ads", "text/x-ada");
      Extension ("md", "text/markdown");
      Extension ("json", "application/json");
      Extension ("xml", "application/xml");
      Extension ("png", "image/png");
      Extension ("jpg", "image/jpeg");
      Extension ("jpeg", "image/jpeg");
      Extension ("pdf", "application/pdf");
      Extension ("zip", "application/zip");
      Extension ("docx", Word_Document);
      Extension ("xlsx", Spreadsheet);
      Extension ("tar", "application/x-tar");
      Extension ("tar.gz", "application/gzip-tar");
      Extension ("gz", "application/gzip");
      Extension ("mp3", "audio/mpeg");
      Extension ("wav", "audio/wav");
      Extension ("mp4", "video/mp4");

      Icon ("inode/directory", "folder");
      Icon ("inode/symlink", "link");
      Icon ("application/x-executable", "executable");
      Icon ("text/plain", "text");
      Icon ("text/x-ada", "ada");
      Icon ("text/markdown", "text");
      Icon ("application/json", "text");
      Icon ("application/xml", "text");
      Icon ("image/png", "image");
      Icon ("image/jpeg", "image");
      Icon ("application/pdf", "text");
      Icon ("application/zip", "unknown");
      Icon (Word_Document, "text");
      Icon (Spreadsheet, "text");
      Icon ("application/x-tar", "unknown");
      Icon ("application/gzip-tar", "unknown");
      Icon ("application/gzip", "unknown");
      Icon ("audio/mpeg", "unknown");
      Icon ("audio/wav", "unknown");
      Icon ("video/mp4", "unknown");
      Icon ("application/octet-stream", "unknown");
      return Result;
   end Default_Classification;

   function Normalized_Extension_Of
     (Name     : String;
      Dotfiles : Boolean := False)
      return String
   is
      Clean : constant String := Leaf_Name (Name);
      --  Files.Types' one rule for where an extension starts.
      Dot   : constant Natural := Files.Name_Parts.Extension_Start (Clean);
   begin
      if Dot /= 0 then
         return Normalize_Extension (Clean (Dot + 1 .. Clean'Last));
      elsif Dotfiles
        and then Clean'Length > 1
        and then Clean (Clean'First) = '.'
        and then Ada.Strings.Fixed.Index (Clean (Clean'First + 1 .. Clean'Last), ".") = 0
      then
         --  ".gitignore": its only dot leads, which the rule counts as name.
         return Normalize_Extension (Clean (Clean'First + 1 .. Clean'Last));
      end if;
      return "";
   end Normalized_Extension_Of;

   function Filetype_For_Name
     (Extensions : String_Maps.Map;
      Name       : String)
      return String
   is
      Clean : constant String := Leaf_Name (Name);
   begin
      --  Every dot that could start an extension under Files.Types' rule
      --  (Extension_Start: neither the first character nor the last), the
      --  first one first, so "archive.tar.gz" is tar.gz before gz.
      for Index in Clean'Range loop
         if Clean (Index) = '.'
           and then Index > Clean'First
           and then Index < Clean'Last
         then
            declare
               Candidate : constant String :=
                 Normalize_Extension (Clean (Index + 1 .. Clean'Last));
               Mapped    : constant String :=
                 Filetype_For_Extension (Extensions, Candidate);
            begin
               if Mapped /= "" then
                  return Mapped;
               end if;
            end;
         end if;
      end loop;

      return "";
   end Filetype_For_Name;

   function Is_Extractable_Archive (Name : String) return Boolean is
     (Normalized_Extension_Of (Name) in "zip" | "7z");

   --  Detect_Filetype by the extension map alone.
   function Filetype_By
     (Extensions : String_Maps.Map;
      Kind       : Files.Types.Item_Kind;
      Name       : String)
      return String
   is
   begin
      case Kind is
         when Files.Types.Directory_Item =>
            return "inode/directory";
         when Files.Types.Symlink_Item =>
            return "inode/symlink";
         when Files.Types.Executable_Item =>
            return "application/x-executable";
         when others =>
            declare
               Mapped : constant String := Filetype_For_Name (Extensions, Name);
            begin
               if Mapped /= "" then
                  return Mapped;
               end if;
            end;
      end case;

      return "application/octet-stream";
   end Filetype_By;

   function Detect_Filetype
     (Classes : Classification;
      Kind    : Files.Types.Item_Kind;
      Name    : String)
      return String is (Filetype_By (Classes.Extension_Filetypes, Kind, Name));

   --  Icon_Id_For by the icon map alone.
   function Icon_By
     (Icons    : String_Maps.Map;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String
   is
      Mapped : constant String := Icon_For_Filetype (Icons, Filetype);
   begin
      if Mapped /= "" then
         return Mapped;
      end if;

      case Kind is
         when Files.Types.Directory_Item =>
            return "folder";
         when Files.Types.Symlink_Item =>
            return "link";
         when Files.Types.Executable_Item =>
            return "executable";
         when others =>
            return "unknown";
      end case;
   end Icon_By;

   function Icon_Id_For
     (Classes  : Classification;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String is (Icon_By (Classes.Icon_Mappings, Kind, Filetype));

   function Icon_Name (Icon : Icon_Kind) return String is
   begin
      case Icon is
         when Folder_Icon     => return "folder";
         when Link_Icon       => return "link";
         when Executable_Icon => return "executable";
         when Text_Icon       => return "text";
         when Markdown_Icon   => return "markdown";
         when Ada_Icon        => return "ada";
         when Image_Icon      => return "image";
         when Unknown_Icon    => return "unknown";
      end case;
   end Icon_Name;

   function Label_Key (Label : Kind_Label) return String is
   begin
      case Label is
         when Extension_Label     => return "";
         when Text_Label          => return "info.kind.text";
         when Markdown_Label      => return "info.kind.markdown";
         when Ada_Source_Label    => return "info.kind.source.ada";
         when Json_Source_Label   => return "info.kind.source.json";
         when Xml_Source_Label    => return "info.kind.source.xml";
         when Png_Image_Label     => return "info.kind.image.png";
         when Jpeg_Image_Label    => return "info.kind.image.jpeg";
         when Pdf_Document_Label  => return "info.kind.document.pdf";
         when Word_Document_Label => return "info.kind.document.word";
         when Spreadsheet_Label   => return "info.kind.document.spreadsheet";
         when Archive_Label       => return "info.kind.archive";
         when Audio_Label         => return "info.kind.audio";
         when Video_Label         => return "info.kind.video";
      end case;
   end Label_Key;

   function Extra_Key (Extra : Extra_Fallback) return String is
   begin
      case Extra is
         when Extension_Extra => return "";
         when Text_Extra      => return "info.extra.text";
         when Markdown_Extra  => return "info.extra.markdown";
         when Image_Extra     => return "info.extra.image";
      end case;
   end Extra_Key;

   --  The one MIME table. Exact entries win over the family (prefix) entries;
   --  a filetype in neither is labelled by its extension and shows the
   --  unknown icon. Matching is case-sensitive, as filetypes are stored.
   type Mime_Rule is record
      Mime  : Files.Types.UString;
      Facts : Filetype_Facts;
   end record;

   type Mime_Rules is array (Positive range <>) of Mime_Rule;

   function "+" (Text : String) return Files.Types.UString
     renames Ada.Strings.Unbounded.To_Unbounded_String;

   Exact_Rules : constant Mime_Rules :=
     [(+"text/plain", (Text_Label, Text_Extra, Text_Icon)),
      (+"text/markdown", (Markdown_Label, Markdown_Extra, Markdown_Icon)),
      (+"text/x-ada", (Ada_Source_Label, Extension_Extra, Text_Icon)),
      (+"application/json", (Json_Source_Label, Extension_Extra, Unknown_Icon)),
      (+"application/xml", (Xml_Source_Label, Extension_Extra, Unknown_Icon)),
      (+"image/png", (Png_Image_Label, Image_Extra, Image_Icon)),
      (+"image/jpeg", (Jpeg_Image_Label, Image_Extra, Image_Icon)),
      (+"application/pdf", (Pdf_Document_Label, Extension_Extra, Unknown_Icon)),
      (+"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
       (Word_Document_Label, Extension_Extra, Unknown_Icon)),
      (+"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
       (Spreadsheet_Label, Extension_Extra, Unknown_Icon)),
      (+"application/zip", (Archive_Label, Extension_Extra, Unknown_Icon)),
      (+"application/x-tar", (Archive_Label, Extension_Extra, Unknown_Icon)),
      (+"application/gzip-tar", (Archive_Label, Extension_Extra, Unknown_Icon)),
      (+"application/gzip", (Archive_Label, Extension_Extra, Unknown_Icon)),
      (+"audio/mpeg", (Audio_Label, Extension_Extra, Unknown_Icon)),
      (+"audio/wav", (Audio_Label, Extension_Extra, Unknown_Icon)),
      (+"video/mp4", (Video_Label, Extension_Extra, Unknown_Icon)),
      (+"application/octet-stream", (Extension_Label, Extension_Extra, Unknown_Icon))];

   Family_Rules : constant Mime_Rules :=
     [(+"image/", (Extension_Label, Image_Extra, Image_Icon)),
      (+"text/", (Extension_Label, Extension_Extra, Text_Icon))];

   function Facts_For (Filetype : String) return Filetype_Facts is
      use type Files.Types.UString;
   begin
      for Rule of Exact_Rules loop
         if Rule.Mime = Filetype then
            return Rule.Facts;
         end if;
      end loop;

      for Rule of Family_Rules loop
         if Files.Text_Basics.Starts_With (Filetype, Ada.Strings.Unbounded.To_String (Rule.Mime)) then
            return Rule.Facts;
         end if;
      end loop;

      return (others => <>);
   end Facts_For;

   function Resolve_Icon
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Icon_Id  : String)
      return Icon_Kind
   is
   begin
      for Icon in Icon_Kind loop
         if Icon_Name (Icon) = Icon_Id then
            return Icon;
         end if;
      end loop;

      case Kind is
         when Files.Types.Directory_Item =>
            return Folder_Icon;
         when Files.Types.Executable_Item =>
            return Executable_Icon;
         when Files.Types.Symlink_Item =>
            return Link_Icon;
         when Files.Types.Regular_File_Item | Files.Types.Other_Item | Files.Types.Unknown_Item =>
            return Facts_For (Filetype).Icon;
      end case;
   end Resolve_Icon;

end Files.File_Types;
