separate (Files.Model)
procedure Begin_Tree_Pick
  (Model          : in out Window_Model;
   Mode           : Tree_Pick_Mode;
   Sources        : Files.Types.String_Vectors.Vector;
   Initial_Target : String) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Tree_Pick_Mode_Value := Mode;
   Model.Tree_Pick_Opened_Panel := Mode /= Pick_None and then not Model.Tree_Panel_Open;
   if Mode /= Pick_None then
      Claim_Overlay_Input (Model);
      --  The picker has its own highlight; the tree's keyboard turn ends.
      Model.Tree_Keyboard_Value := False;
   end if;
   Model.Tree_Pick_Sources_Value := Sources;
   Model.Tree_Pick_Target_Value := To_Unbounded_String (Initial_Target);
end Begin_Tree_Pick;
