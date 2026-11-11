separate (Files.Model)
procedure Close_Tree_Panel
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Tree_Panel_Open := False;
   --  Closing the sidebar also abandons any in-flight destination picker so
   --  a later reopen starts clean. Whether the picker opened the sidebar is
   --  kept for End_Tree_Pick, which reads it after closing.
   Model.Tree_Pick := (Opened_Panel => Model.Tree_Pick.Opened_Panel, others => <>);
   Model.Tree_Panel_Scroll := 0;
   Model.Tree_Keyboard_Value := False;
end Close_Tree_Panel;
