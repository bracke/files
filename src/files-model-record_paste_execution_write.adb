separate (Files.Model)
procedure Record_Paste_Execution_Write
  (Model       : in out Window_Model;
   Dest_Path   : Files.Types.UString;
   Source_Path : Files.Types.UString;
   Name        : String;
   Identity    : String;
   Tree_Revision : String;
   Verified    : Boolean) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Paste_Exec.Cursor := Model.Paste_Exec.Cursor + 1;
   Model.Paste_Exec.Done := Model.Paste_Exec.Done + 1;
   Model.Paste_Exec.Current := To_Unbounded_String (Name);
   if Length (Model.Paste_Exec.First_Dest) = 0 then
      Model.Paste_Exec.First_Dest := Dest_Path;
   end if;
   Model.Paste_Exec.Undo_From.Append (Dest_Path);
   Model.Paste_Exec.Undo_To.Append (Source_Path);
   Model.Paste_Exec.Identities.Append
     (To_Unbounded_String (Identity));
   Model.Paste_Exec.Tree_Revisions.Append
     (To_Unbounded_String (Tree_Revision));
   if Model.Paste_Exec.Verified_Created_Count + 1 =
        Natural (Model.Paste_Exec.Undo_From.Length)
     and then Verified
   then
      Model.Paste_Exec.Verified_Created_Count :=
        Model.Paste_Exec.Verified_Created_Count + 1;
   end if;
end Record_Paste_Execution_Write;
