with Files.Model;
with Files.Settings;

--  Test access to Files.Operations.Paste's private part.
package Files.Operations.Paste.Testing is

   --  Finalize_Paste_Execution with a failed move's kept copy.
   --  @param Model Window whose paste finishes.
   --  @param Settings Current settings.
   --  @param Error_Key Mid-run failure, or "".
   --  @param Dest The kept copy's path.
   --  @param Source Its still present source.
   --  @param Identity The copy's identity.
   --  @param Tree_Revision The copy's revision.
   --  @return The paste's result.
   function Finalize_Paste_With_Kept_Copy
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Error_Key : String;
      Dest, Source, Identity, Tree_Revision : String)
      return Operation_Result;

   --  Arm a paste (Files.Model.Pasting.Begin_Execution) with the copy context
   --  its writes share when there is more than one: a batch transport, so
   --  made here and not by the model.
   --
   --  @param Model Model to update.
   --  @param Actions Fully resolved paste actions.
   --  @param Mode Copy or move for the whole batch.
   --  @param Clear_Clipboard Whether finishing a move clears the clipboard.
   procedure Begin_Paste_Execution
     (Model           : in out Files.Model.Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System_Types.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True);

end Files.Operations.Paste.Testing;
