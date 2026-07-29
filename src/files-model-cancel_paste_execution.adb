separate (Files.Model)
   procedure Cancel_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Cancelled_Value := True;
   end Cancel_Paste_Execution;
