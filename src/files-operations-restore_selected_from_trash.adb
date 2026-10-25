separate (Files.Operations)
function Restore_Selected_From_Trash
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
   First_Path : Unbounded_String;
begin
   if Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Restore);
   end if;
   if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
      return Disabled (Model, "error.selection.empty");
   end if;

   for Item of Items loop
      exit when Files.Job_Context.Cancelled;
      if Length (First_Path) = 0 then
         First_Path := Item.Full_Path;
      end if;

      declare
         Original : constant String := Files.File_System.Trash_Original_Path (To_String (Item.Full_Path));
         Mutation : constant Files.File_System.Mutation_Result :=
           Files.File_System.Restore_From_Trash (To_String (Item.Full_Path));
      begin
         if Mutation.Success then
            Files.Model.Note_Path_Move (Model, To_String (Item.Full_Path), Original);
         end if;
         if not Mutation.Success then
            Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
            declare
               Reload : constant Operation_Result :=
                 Reload_With_Error (Model, Settings, To_String (Mutation.Error_Key));
               pragma Unreferenced (Reload);
            begin
               null;
            end;
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
end Restore_Selected_From_Trash;
