separate (Files.Operations)
   function Delete_Selected_Permanently
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      end if;

      for Item of Items loop
         if not Exists_Safely (To_String (Item.Full_Path)) then
            Files.Model.Set_Error (Model, "error.permanent_delete.failed");
            declare
               Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
               pragma Unreferenced (Reload);
            begin
               Files.Model.Set_Error (Model, "error.permanent_delete.failed");
            end;
            return Make_Result
              (Operation_Failed, "error.permanent_delete.failed", To_String (Item.Full_Path));
         end if;
      end loop;

      for Item of Items loop
         if Length (First_Path) = 0 then
            First_Path := Item.Full_Path;
         end if;

         declare
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Delete_Permanently (To_String (Item.Full_Path));
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
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
   end Delete_Selected_Permanently;
