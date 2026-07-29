separate (Files.Operations.Transfer)
   function Advance_Paste_Execution
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Positive)
      return Operation_Result
   is
      Processed : Natural := 0;
   begin
      if not Files.Model.Paste_Execution_Is_Active (Model) then
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      while Processed < Max_Items
        and then not Files.Model.Paste_Execution_Cancelled (Model)
        and then Files.Model.Paste_Execution_Cursor (Model)
                 < Files.Model.Paste_Execution_Action_Count (Model)
      loop
         declare
            Index  : constant Positive := Files.Model.Paste_Execution_Cursor (Model) + 1;
            Action : constant Files.Paste.Resolved_Action :=
              Files.Model.Paste_Execution_Action (Model, Index);
         begin
            if Action.Skip then
               Files.Model.Skip_Paste_Execution_Action (Model);
            else
               declare
                  Replaced_Trash : Files.Types.UString := Null_Unbounded_String;
               begin
                  if Action.Replaced
                    and then not Clear_Replaced_Destination
                                   (To_String (Action.Dest_Path),
                                    To_String (Action.Source_Path),
                                    Replaced_Trash)
                  then
                     return Finalize_Paste_Execution (Model, Settings, "error.drop.failed");
                  end if;

                  declare
                     Plans : Files.File_System.Drop_Import_Plan_Vectors.Vector;
                  begin
                     Plans.Append
                       (Files.File_System.Drop_Import_Plan'
                          (Source_Path      => Action.Source_Path,
                           Destination_Path => Action.Dest_Path,
                           Mode             => Files.Model.Paste_Execution_Mode (Model),
                           Valid            => True,
                           Error_Key        => Null_Unbounded_String));
                     declare
                        Mutation : constant Files.File_System.Mutation_Result :=
                          Files.File_System.Execute_Drop_Import (Plans);
                     begin
                        if not Mutation.Success then
                           --  The destination was just cleared but the write
                           --  failed: put the trashed original back so a mid-paste
                           --  failure never loses the pre-existing file.
                           if Length (Replaced_Trash) > 0 then
                              declare
                                 Restored : constant Files.File_System.Mutation_Result :=
                                   Files.File_System.Restore_From_Trash (To_String (Replaced_Trash));
                                 pragma Unreferenced (Restored);
                              begin
                                 null;
                              end;
                           end if;
                           return Finalize_Paste_Execution
                             (Model, Settings, To_String (Mutation.Error_Key));
                        end if;
                     end;
                  end;

                  --  Write succeeded: track the overwritten original's trash
                  --  location so the paste's undo entry can restore it.
                  if Length (Replaced_Trash) > 0 then
                     Files.Model.Record_Paste_Execution_Replaced_Trash (Model, Replaced_Trash);
                  end if;
               end;

               Files.Model.Record_Paste_Execution_Write
                 (Model,
                  Action.Dest_Path,
                  Action.Source_Path,
                  Ada.Directories.Simple_Name (To_String (Action.Dest_Path)));
            end if;
         end;
         Processed := Processed + 1;
      end loop;

      if Files.Model.Paste_Execution_Cancelled (Model)
        or else Files.Model.Paste_Execution_Cursor (Model)
                >= Files.Model.Paste_Execution_Action_Count (Model)
      then
         return Finalize_Paste_Execution (Model, Settings, "");
      end if;

      return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
   end Advance_Paste_Execution;
