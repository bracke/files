separate (Files.File_System)
function Extra_Info_Of
  (Path     : String;
   Kind     : Files.Types.Item_Kind;
   Filetype : String)
   return Files.Extra_Info.Info is
begin
   case Kind is
      when Files.Types.Directory_Item =>
         return Directory_Count_Info (Path);
      when Files.Types.Executable_Item =>
         return Executable_Format_Info (Path);
      when Files.Types.Symlink_Item =>
         return Symlink_Target_Info (Path);
      when Files.Types.Regular_File_Item =>
         if Filetype = "text/plain" then
            return Text_Metadata_Info ("text", Path);
         elsif Filetype = "text/x-ada" then
            return Text_Metadata_Info ("source.ada", Path);
         elsif Filetype = "application/json" then
            return Text_Metadata_Info ("source.json", Path);
         elsif Filetype = "application/xml" then
            return Text_Metadata_Info ("source.xml", Path);
         elsif Filetype = "text/markdown" then
            return Text_Metadata_Info ("markdown", Path);
         elsif Filetype = "image/png" or else Filetype = "image/jpeg" then
            return Image_Dimensions_Info (Path, Filetype);
         elsif Filetype = "application/pdf" then
            return Pdf_Page_Count_Info (Path);
         elsif Filetype = "application/zip" then
            return Zip_Entry_Count_Info (Path, Files.Extra_Info.Archive_Entries, "zip");
         elsif Filetype = "application/gzip-tar" then
            return Files.Extra_Info.Make (Files.Extra_Info.Archive_Format, Value => "gzip");
         elsif Filetype = "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then
            return Zip_Entry_Count_Info (Path, Files.Extra_Info.Office_Entries, "docx");
         elsif Filetype = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" then
            return Zip_Entry_Count_Info (Path, Files.Extra_Info.Office_Entries, "xlsx");
         elsif Filetype = "application/x-tar" then
            return Files.Extra_Info.Make (Files.Extra_Info.Archive_Format, Value => "tar");
         elsif Filetype = "application/gzip" then
            return Files.Extra_Info.Make (Files.Extra_Info.Archive_Format, Value => "gzip");
         elsif Filetype = "audio/mpeg" or else Filetype = "audio/wav" then
            return Files.Extra_Info.Make (Files.Extra_Info.Media_Kind, Value => "audio");
         elsif Filetype = "video/mp4" then
            return Files.Extra_Info.Make (Files.Extra_Info.Media_Kind, Value => "video");
         end if;
      when others =>
         null;
   end case;

   return Files.Extra_Info.No_Info;
end Extra_Info_Of;
