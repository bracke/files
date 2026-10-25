separate (Files.Model)
procedure Skip_Paste_Execution_Action
  (Model : in out Window_Model) is
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Paste_Exec.Cursor := Model.Paste_Exec.Cursor + 1;
end Skip_Paste_Execution_Action;
