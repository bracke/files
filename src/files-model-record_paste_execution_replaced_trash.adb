separate (Files.Model)
procedure Record_Paste_Execution_Replaced_Trash
  (Model      : in out Window_Model;
   Trash_Path : Files.Types.UString;
   Identity : String;
   Original_Path : String := "") is
   function Identity_Matches (Path, Expected : String) return Boolean
     renames Files.File_System.Entry_Identity_Matches;
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Paste_Exec.Replaced_Trash.Append (Trash_Path);
   Model.Paste_Exec.Replaced_Identities.Append (To_Unbounded_String (Identity));
   Model.Paste_Exec.Replaced_Targets.Append (To_Unbounded_String
     (if Original_Path /= "" then Original_Path
      else Files.File_System.Trash_Original_Path (To_String (Trash_Path))));
   if Model.Paste_Exec.Verified_Replaced_Count + 1 =
        Natural (Model.Paste_Exec.Replaced_Trash.Length)
     and then Identity_Matches (To_String (Trash_Path), Identity)
   then
      Model.Paste_Exec.Verified_Replaced_Count :=
        Model.Paste_Exec.Verified_Replaced_Count + 1;
   end if;
end Record_Paste_Execution_Replaced_Trash;
