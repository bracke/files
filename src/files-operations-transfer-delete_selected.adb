separate (Files.Operations.Transfer)
   function Delete_Selected
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model)
      return Operation_Result
   is
      Items      : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
      First_Path : Unbounded_String;
      Undo_From  : Files.Types.String_Vectors.Vector;
      Undo_To    : Files.Types.String_Vectors.Vector;
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      elsif not Files.File_System.Trash_Is_Available then
         Files.Model.Set_Error (Model, "error.trash.unavailable");
         return Make_Result (Operation_Failed, "error.trash.unavailable");
      end if;

      for Item of Items loop
         declare
            Preflight : constant Files.File_System.Mutation_Result :=
              Files.File_System.Move_To_Trash_Preflight (To_String (Item.Full_Path));
         begin
            if Preflight.Success then
               null;
            else
               Files.Model.Set_Error (Model, To_String (Preflight.Error_Key));
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Preflight.Error_Key));
               end;
               return Make_Result
                 (Operation_Failed, To_String (Preflight.Error_Key), To_String (Item.Full_Path));
            end if;
         end;
      end loop;

      for Item of Items loop
         if not Exists_Safely (To_String (Item.Full_Path)) then
            Files.Model.Set_Error (Model, "error.trash.failed");
            declare
               Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
               pragma Unreferenced (Reload);
            begin
               Files.Model.Set_Error (Model, "error.trash.failed");
            end;
            return Make_Result (Operation_Failed, "error.trash.failed", To_String (Item.Full_Path));
         end if;
      end loop;

      for Item of Items loop
         if Length (First_Path) = 0 then
            First_Path := Item.Full_Path;
         end if;

         declare
            Trashed  : Files.Types.UString;
            Mutation : constant Files.File_System.Mutation_Result :=
              Files.File_System.Move_To_Trash (To_String (Item.Full_Path), Trashed);
         begin
            if not Mutation.Success then
               Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               --  Record an undo covering whatever was already trashed before this
               --  mid-batch failure (a race can make a later item fail after
               --  earlier ones moved), so those items remain Ctrl-Z-restorable
               --  instead of being stranded in the trash.
               if not Undo_From.Is_Empty then
                  Files.Model.Record_Undo
                    (Model, Files.Model.Undo_Restore_Trash, Undo_From, Undo_To,
                     Redoable => False);
               end if;
               declare
                  Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
                  pragma Unreferenced (Reload);
               begin
                  Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));
               end;
               return Make_Result (Operation_Failed, To_String (Mutation.Error_Key), To_String (Item.Full_Path));
            end if;
            Undo_From.Append (Trashed);
            Undo_To.Append (Item.Full_Path);
         end;
      end loop;

      --  Restoring from trash reproduces the original path, but re-trashing
      --  allocates a fresh trash location, so this entry is undo-only.
      Files.Model.Record_Undo
        (Model, Files.Model.Undo_Restore_Trash, Undo_From, Undo_To,
         Redoable => False);

      declare
         Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);
      begin
         if Reload.Status /= Operation_Success then
            return Reload;
         end if;
      end;

      return Make_Result (Operation_Success, Path => To_String (First_Path));
   end Delete_Selected;
