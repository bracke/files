separate (Files.Model)
procedure Begin_Tree_Pick
  (Model          : in out Window_Model;
   Mode           : Tree_Pick_Mode;
   Sources        : Files.Types.String_Vectors.Vector;
   Initial_Target : String) is
begin
   Touch (Model);
   Model.Tree_Pick :=
     (Mode         => Mode,
      Sources      => Sources,
      Target       => To_Unbounded_String (Initial_Target),
      Opened_Panel => Mode /= Pick_None and then not Model.Tree_Panel_Open);
   if Mode /= Pick_None then
      Claim_Overlay_Input (Model);
      --  The picker has its own highlight; the tree's keyboard turn ends.
      Model.Tree_Keyboard_Value := False;
   end if;
end Begin_Tree_Pick;
