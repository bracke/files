separate (Files.File_System)
function Content_Matches
  (Bytes : String;
   Query : String)
   return Boolean is
begin
   return Files.Types.Text_Contains (Files.Types.Searchable_Text (Bytes), Files.Types.Fold_Case (Query));
end Content_Matches;
