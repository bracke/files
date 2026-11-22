with Files.Model.Recent;
separate (Files.Operations)
function Delete_Selected_Permanently
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items      : constant Files.Items.Item_Vectors.Vector := Files.Model.Selection.Selected_Items (Model);
   First_Path : Unbounded_String;
begin
   declare
      Refusal : constant Operation_Result := Real_Selection_Refusal (Model);
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;

   for Item of Items loop
      exit when Files.Jobs.Context.Cancelled;
      --  refusal-safe: a refused lookup refuses the delete
      if not Files.IO.Fs_Primitives.Entry_Exists (To_String (Item.Full_Path)) then
         Reload_With_Error (Model, Settings, "error.permanent_delete.failed", To_String (Item.Full_Path));
         return Make_Result
           (Operation_Failed, "error.permanent_delete.failed", To_String (Item.Full_Path));
      end if;
   end loop;

   for Item of Items loop
      exit when Files.Jobs.Context.Cancelled;
      if Length (First_Path) = 0 then
         First_Path := Item.Full_Path;
      end if;

      declare
         In_Trash : constant Boolean := Is_Trash_Child (To_String (Item.Full_Path));
         --  A trashed item's labels went into the trash with it.
         Labeled  : constant String := To_String (Item.Full_Path);
         Mutation : constant Files.File_System.Mutation_Result :=
           (if In_Trash
            then Files.File_System.Trash.Delete_Trashed_Item
                   (To_String (Item.Full_Path))
            else Files.File_System.Delete_Permanently
                   (To_String (Item.Full_Path)));
      begin
         if Mutation.Success then
            Files.Model.Recent.Note_Path_Removed (Model, Labeled);
         else
            Reload_With_Error (Model, Settings, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
         end if;
      end;
   end loop;

   declare
      Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
   begin
      if Reload.Status /= Operation_Success then
         return Reload;
      end if;
   end;

   return Make_Result (Operation_Success, Path => To_String (First_Path));
end Delete_Selected_Permanently;
