separate (Files.Operations.Compress_Selected)
function Publish_Archive
  (Stage, Staged, Output_Path, Archive_Name : String; Status : Zlib.Status_Code)
   return Operation_Result
is
   --  What identifies the published archive, for its Undo.
   Identity, Tree_Revision : Unbounded_String;
begin
   if Status /= Zlib.Ok then
      --  Why zlib refused, for a report: the message stays general.
      Files.Diagnostics.Trace ("Files.Operations", "compress_status=" & Status'Image & ",archive=" & Output_Path);
   end if;
   if Status /= Zlib.Ok or else Files.Jobs.Context.Cancelled
     or else not Publish_Staged (Staged, Output_Path, Identity, Tree_Revision)
   then
      Discard_Stage (Stage);
      return Failed;
   end if;
   Discard_Stage (Stage);
   Record_Undo
     (Model, Files.Undo.History.Undo_Delete_Created,
      Published
        (Files.Undo.History.Undo_Item_Vectors.To_Vector
           ((From          => To_Unbounded_String (Output_Path),
             Identity      => Identity,
             Tree_Revision => Tree_Revision,
             others        => <>), 1)),
      Redoable => False);

   --  Reload so the new archive appears, and select it.
   declare
      Reloaded : constant Operation_Result := Reload_Current_Directory (Model, Settings, Archive_Name);
   begin
      if Reloaded.Status /= Operation_Success then
         null;
      elsif Others_Skipped > 0 then
         --  Its message names links too, so it covers a mix of both.
         Files.Model.Set_Error (Model, "error.compress.special_skipped");
      elsif Links_Skipped > 0 then
         Files.Model.Set_Error (Model, "error.compress.links_skipped");
      end if;
      return Reloaded;
   end;
end Publish_Archive;
