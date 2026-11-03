separate (Files.Model)
procedure Begin_Paste_Execution
  (Model           : in out Window_Model;
   Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
   Mode            : Files.File_System.Drop_Import_Mode;
   Clear_Clipboard : Boolean := True;
   Batch           : Files.Copy_Context.Session := Files.Copy_Context.Empty_Session)
is
   Writes : Natural := 0;
begin
   --  The previous helpers' handles are released (see Clear_Paste_Execution).
   Model.Paste_Exec_Job := Released_Transfer;
   Model.Operation_Job := Released_Process;
   Model.Refresh_Job := Released_Process;
   Model.Operation_Label_Key := Null_Unbounded_String;
   Touch (Model);
   Claim_Overlay_Input (Model);
   for Action of Actions loop
      if not Action.Skip then
         Writes := Writes + 1;
      end if;
   end loop;

   Model.Paste_Exec :=
     (Active           => True,
      Actions          => Actions,
      Total            => Writes,
      Copy_Context     => Batch,
      Mode             => Mode,
      Clears_Clipboard => Clear_Clipboard,
      others           => <>);
end Begin_Paste_Execution;
