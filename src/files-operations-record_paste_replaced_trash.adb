separate (Files.Operations)
procedure Record_Paste_Replaced_Trash
  (Model         : in out Files.Model.Window_Model;
   Trash_Path    : Files.Types.UString;
   Identity      : String;
   Original_Path : String)
is
   Original : constant String :=
     (if Original_Path /= "" then Original_Path
      else Files.File_System.Trash_Original_Path (To_String (Trash_Path)));
   --  The live entry is checked only while every earlier original verified.
   Verified : constant Boolean :=
     Files.Model.Paste_Execution_Replaced_Extends_Verified (Model)
     and then Files.File_System.Entry_Identity_Matches (To_String (Trash_Path), Identity);
begin
   Files.Model.Record_Paste_Execution_Replaced_Trash
     (Model, Trash_Path, Identity, Original, Verified);
end Record_Paste_Replaced_Trash;
