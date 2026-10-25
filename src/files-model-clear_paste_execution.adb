separate (Files.Model)
procedure Clear_Paste_Execution
  (Model : in out Window_Model) is
begin
   Files.Transfer_Jobs.Reset (Model.Paste_Exec_Job);
   Files.Process_Jobs.Reset (Model.Operation_Job);
   Model.Operation_Label_Key := Null_Unbounded_String;
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Paste_Exec := (others => <>);
end Clear_Paste_Execution;
