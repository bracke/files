separate (Files.Rendering.Build_Snapshot)
   function Filetype_Extra
     (Item : Files.File_System.Directory_Item)
      return UString
   is
      Type_Name : constant String := To_String (Item.Filetype);

      function Token_Detail (Token : String) return UString is
         Separator : constant Natural := Ada.Strings.Fixed.Index (Token, "|");

         function Prefix_Value
           (Prefix_Key : String;
            Value      : String;
            Suffix_Key : String)
            return String
         is
            Prefix : constant String :=
              Ada.Strings.Fixed.Trim (Files.Localization.Text (Prefix_Key), Ada.Strings.Right);
            Suffix : constant String :=
              Ada.Strings.Fixed.Trim (Files.Localization.Text (Suffix_Key), Ada.Strings.Left);
         begin
            if Suffix'Length > 0
              and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
            then
               return Prefix & " " & Value & " " & Suffix;
            else
               return Prefix & " " & Value & Suffix;
            end if;
         end Prefix_Value;

         function Prefix_Localized_Value
           (Prefix_Key : String;
            Value_Key  : String;
            Suffix_Key : String)
            return String
         is
         begin
            return Prefix_Value (Prefix_Key, Files.Localization.Text (Value_Key), Suffix_Key);
         end Prefix_Localized_Value;

         function Lines_And_Encoding
           (Lines_Prefix_Key : String;
            Lines            : String;
            Lines_Suffix_Key : String;
            Encoding         : String)
            return String
         is
         begin
            return
              Prefix_Value (Lines_Prefix_Key, Lines, Lines_Suffix_Key)
              & " "
              & Prefix_Localized_Value
                ("info.extra.encoding.prefix",
                 "info.extra.encoding." & Encoding,
                 "info.extra.encoding.suffix");
         end Lines_And_Encoding;
      begin
         if Separator <= Token'First or else Separator >= Token'Last then
            return Null_Unbounded_String;
         end if;

         declare
            Key   : constant String := Token (Token'First .. Separator - 1);
            Value : constant String := Token (Separator + 1 .. Token'Last);
            Second : constant Natural := Ada.Strings.Fixed.Index (Value, "|");
         begin
            if Key = "executable.format" then
               return
                 To_Unbounded_String
                   (Prefix_Localized_Value
                      ("info.extra.executable.format.prefix",
                       "info.extra.executable.format." & Value,
                       "info.extra.executable.format.suffix"));
            elsif Key = "directory.count" then
               return
                 To_Unbounded_String
                   (Prefix_Value
                      ("info.extra.directory.count.prefix", Value, "info.extra.directory.count.suffix"));
            elsif Key = "text.lines" then
               return
                 To_Unbounded_String
                   (Prefix_Value ("info.extra.text.lines.prefix", Value, "info.extra.text.lines.suffix"));
            elsif Key = "text.lines_encoding" and then Second > Value'First then
               declare
                  Lines    : constant String := Value (Value'First .. Second - 1);
                  Encoding : constant String := Value (Second + 1 .. Value'Last);
               begin
                  return
                    To_Unbounded_String
                      (Lines_And_Encoding
                         ("info.extra.text.lines.prefix",
                          Lines,
                          "info.extra.text.lines.suffix",
                          Encoding));
               end;
            elsif Key = "markdown.lines" then
               return
                 To_Unbounded_String
                   (Prefix_Value
                      ("info.extra.markdown.lines.prefix", Value, "info.extra.markdown.lines.suffix"));
            elsif Key = "markdown.lines_encoding" and then Second > Value'First then
               declare
                  Lines    : constant String := Value (Value'First .. Second - 1);
                  Encoding : constant String := Value (Second + 1 .. Value'Last);
               begin
                  return
                    To_Unbounded_String
                      (Lines_And_Encoding
                         ("info.extra.markdown.lines.prefix",
                          Lines,
                          "info.extra.markdown.lines.suffix",
                          Encoding));
               end;
            elsif Key = "image.dimensions" then
               return
                 To_Unbounded_String
                   (Prefix_Value
                      ("info.extra.image.dimensions.prefix", Value, "info.extra.image.dimensions.suffix"));
            elsif Key = "symlink.target" then
               return
                 To_Unbounded_String
                   (Prefix_Value ("info.extra.symlink.target.prefix", Value, "info.extra.symlink.target.suffix"));
            elsif Key = "document.kind" then
               return To_Unbounded_String (Files.Localization.Text ("info.extra.document." & Value));
            elsif Key = "document.pdf.pages" then
               return
                 To_Unbounded_String
                   (Prefix_Value
                      ("info.extra.document.pdf.pages.prefix", Value, "info.extra.document.pdf.pages.suffix"));
            elsif Key = "archive.format" then
               return
                 To_Unbounded_String
                   (Prefix_Localized_Value
                      ("info.extra.archive.format.prefix",
                       "info.extra.archive.format." & Value,
                       "info.extra.archive.format.suffix"));
            elsif Key = "archive.zip.entries" or else Key = "archive.gzip-tar.entries" then
               return
                 To_Unbounded_String
                   (Prefix_Value
                      ("info.extra.archive.entries.prefix", Value, "info.extra.archive.entries.suffix"));
            elsif Key = "office.docx.entries" then
               return
                 To_Unbounded_String
                   (Prefix_Value
                      ("info.extra.office.docx.prefix", Value, "info.extra.office.entries.suffix"));
            elsif Key = "office.xlsx.entries" then
               return
                 To_Unbounded_String
                   (Prefix_Value
                      ("info.extra.office.xlsx.prefix", Value, "info.extra.office.entries.suffix"));
            elsif Key = "media.kind" then
               return To_Unbounded_String (Files.Localization.Text ("info.extra.media." & Value));
            elsif Key = "source.ada.lines_encoding" and then Second > Value'First then
               declare
                  Lines    : constant String := Value (Value'First .. Second - 1);
                  Encoding : constant String := Value (Second + 1 .. Value'Last);
               begin
                  return
                    To_Unbounded_String
                      (Lines_And_Encoding
                         ("info.extra.source.ada.prefix",
                          Lines,
                          "info.extra.source.lines.suffix",
                          Encoding));
               end;
            elsif Key = "source.json.lines_encoding" and then Second > Value'First then
               declare
                  Lines    : constant String := Value (Value'First .. Second - 1);
                  Encoding : constant String := Value (Second + 1 .. Value'Last);
               begin
                  return
                    To_Unbounded_String
                      (Lines_And_Encoding
                         ("info.extra.source.json.prefix",
                          Lines,
                          "info.extra.source.lines.suffix",
                          Encoding));
               end;
            elsif Key = "source.xml.lines_encoding" and then Second > Value'First then
               declare
                  Lines    : constant String := Value (Value'First .. Second - 1);
                  Encoding : constant String := Value (Second + 1 .. Value'Last);
               begin
                  return
                    To_Unbounded_String
                      (Lines_And_Encoding
                         ("info.extra.source.xml.prefix",
                          Lines,
                          "info.extra.source.lines.suffix",
                          Encoding));
               end;
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

         return
           Files.Localization.Text ("info.extra.extension.prefix")
           & Extension
           & Files.Localization.Text ("info.extra.extension.suffix");
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
               declare
                  Prefix : constant String :=
                    Ada.Strings.Fixed.Trim
                      (Files.Localization.Text ("info.extra.executable.size.prefix"), Ada.Strings.Right);
                  Suffix : constant String :=
                    Ada.Strings.Fixed.Trim
                      (Files.Localization.Text ("info.extra.executable.size.suffix"), Ada.Strings.Left);
                  --  Group the digits with the locale separator, like every
                  --  other size on screen, instead of a bare Image.
                  Size_Text : constant String := Grouped_Integer_Text (Item.Size);
               begin
                  if Suffix'Length > 0
                    and then Ada.Characters.Handling.Is_Alphanumeric (Suffix (Suffix'First))
                  then
                     return To_Unbounded_String (Prefix & " " & Size_Text & " " & Suffix);
                  else
                     return To_Unbounded_String (Prefix & " " & Size_Text & Suffix);
                  end if;
               end;
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
