separate (Files.Model)
procedure Clear_Paste_Execution
  (Model : in out Window_Model) is
begin
   --  Released, not driven: a helper still running is stopped and reaped
   --  by its last handle going (Files.Process_Jobs).
   Model.Paste_Exec_Job := Released_Transfer;
   Model.Operation_Job := Released_Process;
   Model.Operation_Label_Key := Null_Unbounded_String;
   Model.Revision_Value := Model.Revision_Value + 1;
   Model.Paste_Exec := (others => <>);
end Clear_Paste_Execution;
