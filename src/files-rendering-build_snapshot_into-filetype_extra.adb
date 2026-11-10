with Files.Extra_Info;

separate (Files.Rendering.Build_Snapshot_Into)
   function Filetype_Extra
     (Item : Files.Items.Directory_Item)
      return UString
   is
      Type_Name : constant String := To_String (Item.Filetype);

      --  The extra info in words: each kind its own pattern.
      function Detail (Extra : Files.Extra_Info.Info) return UString is
         Subject : constant String := To_String (Extra.Subject);
         Value   : constant String := To_String (Extra.Value);
         Count   : constant String := Files.Types.Natural_Text (Extra.Count) & (if Extra.Capped then "+" else "");

         function Fill (Key, Name, Text : String) return UString is
           (To_Unbounded_String (Files.Localization.Text ("info.extra." & Key, Name, Text)));

         function Word (Key : String) return String is (Files.Localization.Text ("info.extra." & Key));
      begin
         case Extra.Of_Kind is
            when Files.Extra_Info.None =>
               return Null_Unbounded_String;
            when Files.Extra_Info.Directory_Count =>
               return Fill ("directory.count", "count", Count);
            when Files.Extra_Info.Executable_Format =>
               return Fill ("executable.format", "format", Word ("executable.format." & Value));
            when Files.Extra_Info.Symlink_Target =>
               return Fill ("symlink.target", "target", Value);
            when Files.Extra_Info.Text_Lines =>
               declare
                  --  text and markdown say "lines"; a source names its language.
                  Key : constant String :=
                    (if Subject in "text" | "markdown" then Subject & ".lines" else Subject);
               begin
                  return Fill (Key, "lines", Count)
                    & (if Value = "" then Null_Unbounded_String
                       else " " & Fill ("encoding", "encoding", Word ("encoding." & Value)));
               end;
            when Files.Extra_Info.Image_Dimensions =>
               return Fill ("image.dimensions", "dimensions", Value);
            when Files.Extra_Info.Document_Kind =>
               return To_Unbounded_String (Word ("document." & Value));
            when Files.Extra_Info.Pdf_Pages =>
               return Fill ("document.pdf.pages", "pages", Count);
            when Files.Extra_Info.Archive_Format =>
               return Fill ("archive.format", "format", Word ("archive.format." & Value));
            when Files.Extra_Info.Archive_Entries =>
               return Fill ("archive.entries", "count", Count);
            when Files.Extra_Info.Office_Entries =>
               return Fill ("office." & Subject, "count", Count);
            when Files.Extra_Info.Media_Kind =>
               return To_Unbounded_String (Word ("media." & Value));
         end case;
      end Detail;

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
      declare
         Extra_Text : constant UString := Detail (Item.Filetype_Extra);
      begin
         if Length (Extra_Text) > 0 then
            return Extra_Text;
         end if;
      end;

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
