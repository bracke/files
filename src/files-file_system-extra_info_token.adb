separate (Files.File_System)
   function Extra_Info_Token
     (Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String is
   begin
      case Kind is
         when Files.Types.Directory_Item =>
            return Directory_Count_Token (Path);
         when Files.Types.Executable_Item =>
            return Executable_Format_Token (Path);
         when Files.Types.Symlink_Item =>
            return Files.Platform.Metadata.Symlink_Target_Token (Path);
         when Files.Types.Regular_File_Item =>
            if Filetype = "text/plain" then
               return Text_Metadata_Token ("text", Path);
            elsif Filetype = "text/x-ada" then
               return Text_Metadata_Token ("source.ada", Path);
            elsif Filetype = "application/json" then
               return Text_Metadata_Token ("source.json", Path);
            elsif Filetype = "application/xml" then
               return Text_Metadata_Token ("source.xml", Path);
            elsif Filetype = "text/markdown" then
               return Text_Metadata_Token ("markdown", Path);
            elsif Filetype = "image/png" or else Filetype = "image/jpeg" then
               return Image_Dimensions_Token (Path, Filetype);
            elsif Filetype = "application/pdf" then
               return Pdf_Page_Count_Token (Path);
            elsif Filetype = "application/zip" then
               return Zip_Entry_Count_Token (Path, "archive.zip");
            elsif Filetype = "application/gzip-tar" then
               return "archive.format|gzip";
            elsif Filetype = "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then
               return Zip_Entry_Count_Token (Path, "office.docx");
            elsif Filetype = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" then
               return Zip_Entry_Count_Token (Path, "office.xlsx");
            elsif Filetype = "application/x-tar" then
               return "archive.format|tar";
            elsif Filetype = "application/gzip" then
               return "archive.format|gzip";
            elsif Filetype = "audio/mpeg" or else Filetype = "audio/wav" then
               return "media.kind|audio";
            elsif Filetype = "video/mp4" then
               return "media.kind|video";
            end if;
         when others =>
            null;
      end case;

      return "";
   end Extra_Info_Token;
