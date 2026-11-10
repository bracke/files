separate (Files.Rendering.Build_Snapshot_Into)
   function Filetype_Extra
     (Item : Files.Items.Directory_Item)
      return UString
   is
      Type_Name : constant String := To_String (Item.Filetype);

      --  A token is "kind|value" or "kind|lines|encoding"; the value is the
      --  last field, so it may hold a '|' itself (a link's target).
      function Token_Detail (Token : String) return UString is
         Separator : constant Natural := Ada.Strings.Fixed.Index (Token, "|");

         function Fill (Key, Name, Value : String) return UString is
           (To_Unbounded_String (Files.Localization.Text ("info.extra." & Key, Name, Value)));

         --  The lines sentence, then the encoding one.
         function Lines_And_Encoding (Key, Lines, Encoding : String) return UString is
           (Fill (Key, "lines", Lines) & " "
            & Fill ("encoding", "encoding", Files.Localization.Text ("info.extra.encoding." & Encoding)));
      begin
         if Separator <= Token'First or else Separator >= Token'Last then
            return Null_Unbounded_String;
         end if;

         declare
            Key    : constant String := Token (Token'First .. Separator - 1);
            Value  : constant String := Token (Separator + 1 .. Token'Last);
            Second : constant Natural := Ada.Strings.Fixed.Index (Value, "|");
            Lines  : constant String := (if Second > Value'First then Value (Value'First .. Second - 1) else "");
            Coding : constant String := (if Second > Value'First then Value (Second + 1 .. Value'Last) else "");
         begin
            if Key = "executable.format" then
               return Fill (Key, "format", Files.Localization.Text ("info.extra.executable.format." & Value));
            elsif Key = "archive.format" then
               return Fill (Key, "format", Files.Localization.Text ("info.extra.archive.format." & Value));
            elsif Key in "directory.count" | "archive.zip.entries" | "archive.gzip-tar.entries"
                       | "office.docx.entries" | "office.xlsx.entries"
            then
               return Fill
                 ((if Key = "directory.count" then Key
                   elsif Key (Key'First) = 'a' then "archive.entries"
                   else Key (Key'First .. Key'Last - 8)),
                  "count", Value);
            elsif Key in "text.lines" | "markdown.lines" then
               return Fill (Key, "lines", Value);
            elsif Key = "image.dimensions" then
               return Fill (Key, "dimensions", Value);
            elsif Key = "symlink.target" then
               return Fill (Key, "target", Value);
            elsif Key = "document.pdf.pages" then
               return Fill (Key, "pages", Value);
            elsif Key = "document.kind" then
               return To_Unbounded_String (Files.Localization.Text ("info.extra.document." & Value));
            elsif Key = "media.kind" then
               return To_Unbounded_String (Files.Localization.Text ("info.extra.media." & Value));
            elsif Lines /= "" and then Key in "text.lines_encoding" | "markdown.lines_encoding" then
               return Lines_And_Encoding (Key (Key'First .. Key'Last - 9), Lines, Coding);
            elsif Lines /= ""
              and then Key in "source.ada.lines_encoding" | "source.json.lines_encoding" | "source.xml.lines_encoding"
            then
               return Lines_And_Encoding (Key (Key'First .. Key'Last - 15), Lines, Coding);
            end if;
         end;

         return Null_Unbounded_String;
      end Token_Detail;

      function Extension_Detail
        (Name : String)
         return String
      is
         Extension : constant String := Files.File_Types.Extension_Of (Name);
      begin
         if Extension = "" then
            return Files.Localization.Text ("info.extra.file");
         end if;

         return Files.Localization.Text ("info.extra.extension", "extension", Extension);
      end Extension_Detail;
   begin
      if Length (Item.Filetype_Extra) > 0 then
         declare
            Detail : constant UString := Token_Detail (To_String (Item.Filetype_Extra));
         begin
            if Length (Detail) > 0 then
               return Detail;
            end if;
         end;
      end if;

      case Item.Kind is
         when Files.Types.Directory_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.extra.directory"));
         when Files.Types.Symlink_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.extra.symlink"));
         when Files.Types.Executable_Item =>
            if Item.Size_Available then
               --  Grouped with the locale separator, like every other size on screen.
               return To_Unbounded_String
                 (Files.Localization.Text ("info.extra.executable.size", "size", Grouped_Integer_Text (Item.Size)));
            else
               return
                 To_Unbounded_String (Files.Localization.Text ("info.extra.executable"));
            end if;
         when Files.Types.Other_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.extra.other"));
         when Files.Types.Unknown_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.extra.unknown"));
         when Files.Types.Regular_File_Item =>
            if Type_Name = "text/plain" then
               return To_Unbounded_String (Files.Localization.Text ("info.extra.text"));
            elsif Type_Name = "text/markdown" then
               return To_Unbounded_String (Files.Localization.Text ("info.extra.markdown"));
            elsif Type_Name'Length >= 6
              and then Type_Name (Type_Name'First .. Type_Name'First + 5) = "image/"
            then
               return To_Unbounded_String (Files.Localization.Text ("info.extra.image"));
            elsif Type_Name = "application/octet-stream" then
               return To_Unbounded_String (Extension_Detail (To_String (Item.Name)));
            end if;
      end case;

      return To_Unbounded_String (Extension_Detail (To_String (Item.Name)));
   end Filetype_Extra;
