separate (Files.Rendering.Build_Snapshot)
   function Filetype_Detail
     (Item : Files.File_System.Directory_Item)
      return UString
   is
      function Upper_Extension (Extension : String) return String is
         Result : String (Extension'Range);
      begin
         for Index in Extension'Range loop
            Result (Index) := Ada.Characters.Handling.To_Upper (Extension (Index));
         end loop;

         return Result;
      end Upper_Extension;

      function Extension_File_Label return UString is
         Extension : constant String := Files.File_Types.Extension_Of (To_String (Item.Name));
      begin
         if Extension = "" then
            return To_Unbounded_String (Files.Localization.Text ("info.kind.file"));
         end if;

         return
           To_Unbounded_String (Upper_Extension (Extension));
      end Extension_File_Label;
   begin
      case Item.Kind is
         when Files.Types.Directory_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.kind.directory"));
         when Files.Types.Symlink_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.kind.symlink"));
         when Files.Types.Executable_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.kind.executable"));
         when Files.Types.Regular_File_Item =>
            if To_String (Item.Filetype) = "text/plain" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.text"));
            elsif To_String (Item.Filetype) = "text/markdown" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.markdown"));
            elsif To_String (Item.Filetype) = "text/x-ada" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.source.ada"));
            elsif To_String (Item.Filetype) = "application/json" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.source.json"));
            elsif To_String (Item.Filetype) = "application/xml" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.source.xml"));
            elsif To_String (Item.Filetype) = "image/png" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.image.png"));
            elsif To_String (Item.Filetype) = "image/jpeg" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.image.jpeg"));
            elsif To_String (Item.Filetype) = "application/pdf" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.document.pdf"));
            elsif To_String (Item.Filetype) =
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
            then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.document.word"));
            elsif To_String (Item.Filetype) =
              "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.document.spreadsheet"));
            elsif To_String (Item.Filetype) = "application/zip"
              or else To_String (Item.Filetype) = "application/x-tar"
              or else To_String (Item.Filetype) = "application/gzip-tar"
              or else To_String (Item.Filetype) = "application/gzip"
            then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.archive"));
            elsif To_String (Item.Filetype) = "audio/mpeg"
              or else To_String (Item.Filetype) = "audio/wav"
            then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.audio"));
            elsif To_String (Item.Filetype) = "video/mp4" then
               return To_Unbounded_String (Files.Localization.Text ("info.kind.video"));
            end if;

            return Extension_File_Label;
         when Files.Types.Other_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.kind.other"));
         when Files.Types.Unknown_Item =>
            return To_Unbounded_String (Files.Localization.Text ("info.kind.unknown"));
      end case;

   end Filetype_Detail;
