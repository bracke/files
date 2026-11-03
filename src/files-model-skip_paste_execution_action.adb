separate (Files.Model)
procedure Skip_Paste_Execution_Action
  (Model : in out Window_Model) is
begin
   Touch (Model);
   Model.Paste_Exec.Cursor := Model.Paste_Exec.Cursor + 1;
end Skip_Paste_Execution_Action;
