with Ada.Strings.Unbounded;

with Hostkit.Path_Text;
with Guikit.Utf8.Editing;

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

   function Leaf_Name (Name : String) return String is
      Clean : constant String := Trim_Name (Name);
      First : Natural := Clean'First;
   begin
      for Index in reverse Clean'Range loop
         if Hostkit.Path_Text.Is_Separator_In (Clean, Clean (Index)) then
            First := Index + 1;
            exit;
         end if;
      end loop;

      if Clean = "" or else First > Clean'Last then
         return "";
      end if;

      return Clean (First .. Clean'Last);
   end Leaf_Name;

   function Extension_Of
     (Name     : String;
      Dotfiles : Boolean := False)
      return String
   is
      Clean : constant String := Leaf_Name (Name);
      Dot : Natural := 0;
   begin
      for Index in reverse Clean'Range loop
         if Clean (Index) = '.' then
            Dot := Index;
            exit;
         end if;
      end loop;

      if Dot = 0 or else (Dot = Clean'First and then not Dotfiles) or else Dot = Clean'Last then
         return "";
      end if;

      return Files.Settings.Normalize_Extension (Clean (Dot + 1 .. Clean'Last));
   end Extension_Of;

   function Filetype_For_Name
     (Settings : Files.Settings.Settings_Model;
      Name     : String)
      return String
   is
      Clean : constant String := Leaf_Name (Name);
   begin
      for Index in Clean'Range loop
         if Clean (Index) = '.'
           and then Index > Clean'First
           and then Index < Clean'Last
         then
            declare
               Candidate : constant String :=
                 Files.Settings.Normalize_Extension (Clean (Index + 1 .. Clean'Last));
               Mapped    : constant String :=
                 Files.Settings.Filetype_For_Extension (Settings, Candidate);
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
     (Extension_Of (Name) in "zip" | "7z");

   function Detect_Filetype
     (Settings : Files.Settings.Settings_Model;
      Kind     : Files.Types.Item_Kind;
      Name     : String)
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
               Mapped : constant String := Filetype_For_Name (Settings, Name);
            begin
               if Mapped /= "" then
                  return Mapped;
               end if;
            end;
      end case;

      return "application/octet-stream";
   end Detect_Filetype;

   function Icon_Id_For
     (Settings : Files.Settings.Settings_Model;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String
   is
      Mapped : constant String := Files.Settings.Icon_For_Filetype (Settings, Filetype);
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
   end Icon_Id_For;

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
         if Files.Types.Starts_With (Filetype, Ada.Strings.Unbounded.To_String (Rule.Mime)) then
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
