separate (Files.File_System)
function Text_Metadata_Info
  (Prefix : String;
   Path   : String)
   return Files.Extra_Info.Info
is
   Count  : Natural;
   Capped : Boolean;
begin
   Count_Text_Lines (Path, Count, Capped);
   return Files.Extra_Info.Make
     (Files.Extra_Info.Text_Lines,
      Subject => Prefix, Value => Text_Encoding_Name (Path), Count => Count, Capped => Capped);
end Text_Metadata_Info;
