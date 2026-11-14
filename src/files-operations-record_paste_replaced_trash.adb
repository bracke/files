separate (Files.Operations)
procedure Record_Paste_Replaced_Trash
  (Model         : in out Files.Model.Window_Model;
   Trash_Path    : Files.Types.UString;
   Identity      : String;
   Original_Path : String)
is
   Original : constant String :=
     (if Original_Path /= "" then Original_Path
      else Files.File_System.Trash.Trash_Original_Path (To_String (Trash_Path)));
   --  Each original is verified on its own, against the live entry.
   Verified : constant Boolean := Files.File_System.Entry_Identity_Matches (To_String (Trash_Path), Identity);
begin
   Files.Model.Pasting.Record_Replaced_Trash
     (Model, Trash_Path, Identity, Original, Verified);
end Record_Paste_Replaced_Trash;
