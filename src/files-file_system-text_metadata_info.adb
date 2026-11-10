separate (Files.File_System)
function Text_Metadata_Info
  (Prefix : String;
   Path   : String)
   return Files.Extra_Info.Info is
begin
   return Files.Extra_Info.Make
     (Files.Extra_Info.Text_Lines,
      Subject => Prefix, Value => Text_Encoding_Name (Path), Count => Count_Text_Lines (Path));
end Text_Metadata_Info;
