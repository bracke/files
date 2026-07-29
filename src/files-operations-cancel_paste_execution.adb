separate (Files.Operations)
   procedure Cancel_Paste_Execution
     (Model : in out Files.Model.Window_Model) is
   begin
      if Files.Model.Paste_Execution_Is_Active (Model) then
         Files.Model.Cancel_Paste_Execution (Model);
      end if;
   end Cancel_Paste_Execution;
