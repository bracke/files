separate (Files.Model)
procedure Record_Paste_Execution_Replaced_Trash
  (Model      : in out Window_Model;
   Trash_Path : Files.Types.UString;
   Identity : String;
   Original_Path : String;
   Verified : Boolean) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Paste_Exec.Replaced_Trash.Append (Trash_Path);
   Model.Paste_Exec.Replaced_Identities.Append (To_Unbounded_String (Identity));
   Model.Paste_Exec.Replaced_Targets.Append (To_Unbounded_String (Original_Path));
   if Model.Paste_Exec.Verified_Replaced_Count + 1 =
        Natural (Model.Paste_Exec.Replaced_Trash.Length)
     and then Verified
   then
      Model.Paste_Exec.Verified_Replaced_Count :=
        Model.Paste_Exec.Verified_Replaced_Count + 1;
   end if;
end Record_Paste_Execution_Replaced_Trash;
