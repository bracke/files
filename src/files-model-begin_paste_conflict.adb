separate (Files.Model)
procedure Begin_Paste_Conflict
  (Model           : in out Window_Model;
   Items           : Files.Paste.Work_Item_Vectors.Vector;
   Existing        : Files.Types.String_Vectors.Vector;
   Mode            : Files.File_System.Drop_Import_Mode;
   Index           : Positive;
   Clear_Clipboard : Boolean := True) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Claim_Overlay_Input (Model);
   Model.Paste_Conflict :=
     (Active           => True,
      Items            => Items,
      Existing         => Existing,
      Mode             => Mode,
      Clears_Clipboard => Clear_Clipboard,
      Index            => Index,
      others           => <>);
   for Ignore in Items.First_Index .. Items.Last_Index loop
      Model.Paste_Conflict.Overrides.Append (Files.Paste.Decision_Pending);
   end loop;
end Begin_Paste_Conflict;
