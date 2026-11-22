with Files.Text_Encoding;
with Files.Text_Case;

separate (Files.File_System.Search)
function Content_Matches
  (Bytes : String;
   Query : String)
   return Boolean is
begin
   return Files.Text_Encoding.Text_Contains (Files.Text_Encoding.Searchable_Text (Bytes),
                                         Files.Text_Case.Fold_Case (Query));
end Content_Matches;
