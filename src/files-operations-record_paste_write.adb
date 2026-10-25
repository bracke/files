separate (Files.Operations)
procedure Record_Paste_Write
  (Model         : in out Files.Model.Window_Model;
   Dest_Path     : Files.Types.UString;
   Source_Path   : Files.Types.UString;
   Name          : String;
   Identity      : String;
   Tree_Revision : String;
   Retain_Verified_Snapshot : Boolean := False)
is
   --  The published entry is checked only while every earlier write verified.
   Verified : constant Boolean :=
     Files.Model.Paste_Execution_Write_Extends_Verified (Model)
     and then
       ((Retain_Verified_Snapshot and then Identity /= "")
        or else
          (if Files.Model.Paste_Execution_Mode (Model) = Files.File_System.Drop_Move
           then Files.File_System.Entry_Identity_Matches (To_String (Dest_Path), Identity)
           else Files.File_System.Creation_Matches
             (To_String (Dest_Path), Identity, Tree_Revision)));
begin
   Files.Model.Record_Paste_Execution_Write
     (Model, Dest_Path, Source_Path, Name, Identity, Tree_Revision, Verified);
end Record_Paste_Write;
