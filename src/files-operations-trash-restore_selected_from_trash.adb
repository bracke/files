with Files.Items;
with Files.Model.Recent;
separate (Files.Operations.Trash)
function Restore_Selected_From_Trash
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
      if Length (First_Path) = 0 then
         First_Path := Item.Full_Path;
      end if;

      declare
         Original : constant String := Files.File_System.Trash.Trash_Original_Path (To_String (Item.Full_Path));
         Mutation : constant Files.File_System.Mutation_Result :=
           Files.File_System.Trash.Restore_From_Trash (To_String (Item.Full_Path));
      begin
         if Mutation.Success then
            Files.Model.Recent.Note_Path_Move (Model, To_String (Item.Full_Path), Original);
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
end Restore_Selected_From_Trash;
