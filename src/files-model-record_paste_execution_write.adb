separate (Files.Model)
procedure Record_Paste_Execution_Write
  (Model       : in out Window_Model;
   Dest_Path   : Files.Types.UString;
   Source_Path : Files.Types.UString;
   Name        : String;
   Identity    : String;
   Tree_Revision : String;
   Retain_Verified_Snapshot : Boolean := False) is
   use type Files.File_System.Drop_Import_Mode;
   function Identity_Matches (Path, Expected : String) return Boolean
     renames Files.File_System.Entry_Identity_Matches;
   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean := False) return Boolean
     renames Files.File_System.Creation_Matches;
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
     and then
       ((Retain_Verified_Snapshot and then Identity /= "")
        or else
          (if Model.Paste_Exec.Mode = Files.File_System.Drop_Move
           then Identity_Matches (To_String (Dest_Path), Identity)
           else Creation_Snapshot_Matches
             (To_String (Dest_Path), Identity, Tree_Revision)))
   then
      Model.Paste_Exec.Verified_Created_Count :=
        Model.Paste_Exec.Verified_Created_Count + 1;
   end if;
end Record_Paste_Execution_Write;
