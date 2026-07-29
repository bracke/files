separate (Files.Operations)
   function Open_Selected
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
      return Operation_Result
   is
      Items : constant Files.File_System.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
   begin
      if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
         return Disabled (Model, "error.selection.empty");
      elsif Natural (Items.Length) > 1 then
         declare
            First_Path : Unbounded_String;
            First_Action : Files.Settings.Open_Action := Empty_Action;
            First_Action_Recorded : Boolean := False;
            First_Exit_Status : Integer := 0;
         begin
            for Item of Items loop
               if Item.Kind = Files.Types.Directory_Item then
                  Files.Model.Set_Error (Model, "error.open_action.multi_directory");
                  return
                    Make_Result
                      (Operation_Failed,
                       "error.open_action.multi_directory",
                       To_String (Item.Full_Path));
               end if;
            end loop;

            for Item of Items loop
               declare
                  Lookup : constant Files.Settings.Action_Lookup_Result :=
                    Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);
               begin
                  if Length (First_Path) = 0 then
                     First_Path := Item.Full_Path;
                  end if;

                  if not Lookup.Found then
                     Files.Model.Set_Error (Model, To_String (Lookup.Error_Key));
                     return
                       Make_Result
                         (Operation_Missing_Open_Action,
                          To_String (Lookup.Error_Key),
                          To_String (Item.Full_Path));
                  elsif Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action) then
                     return Unsafe_Open_Action (Model, To_String (Item.Full_Path));
                  end if;

                  declare
                     Action : constant Files.Settings.Open_Action :=
                       Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));
                  begin
                     if not Open_Action_Executable_Is_Available (Action) then
                        Files.Model.Set_Error (Model, "error.open_action.executable_missing");
                        return
                          Make_Result
                            (Operation_Failed,
                             "error.open_action.executable_missing",
                             To_String (Item.Full_Path),
                             Action,
                             Attempted => False,
                             Found     => False);
                     end if;

                     if not First_Action_Recorded then
                        First_Action := Action;
                        First_Action_Recorded := True;
                     end if;
                  end;
               end;
            end loop;

            for Item of Items loop
               declare
                  Lookup : constant Files.Settings.Action_Lookup_Result :=
                    Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);
                  Action : constant Files.Settings.Open_Action :=
                    Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));
                  Exit_Status : Integer := 0;
                  Spawn_OK    : constant Boolean :=
                    Execute_Open_Action (Action, Exit_Status, Detach => True);
               begin
                  --  System-fallback handlers (xdg-open / open / cmd start)
                  --  are launched detached: Spawn_OK reflects whether the
                  --  fork+exec succeeded, not the handler's own exit code.
                  if not Spawn_OK then
                     Files.Model.Set_Error (Model, "error.open_action.execution");
                     return
                       Make_Result
                         (Operation_Failed,
                          "error.open_action.execution",
                          To_String (Item.Full_Path),
                          Action,
                          Attempted => True,
                          Found     => True,
                          Exit_Known => False,
                          Exit_Status => Exit_Status);
                  end if;

                  --  Each launched file joins the recent list, freshest last.
                  Files.Model.Note_Recent_Open (Model, To_String (Item.Full_Path));

                  if To_String (Item.Full_Path) = To_String (First_Path) then
                     First_Exit_Status := Exit_Status;
                  end if;
               end;
            end loop;

            Files.Model.Set_Error (Model, "");
            return
              Make_Result
                (Operation_Action_Executed,
                 Path      => To_String (First_Path),
                 Action    => First_Action,
                 Attempted => First_Action_Recorded,
                 Found     => First_Action_Recorded,
                 --  Detached: started and let go, so there is no exit status.
                 Exit_Known => False,
                 Exit_Status => First_Exit_Status);
         end;
      end if;

      declare
         Prepared : constant Operation_Result := Prepare_Open_Selected_Action (Model, Settings, Modifiers);
      begin
         if Prepared.Status /= Operation_Success then
            return Prepared;
         elsif To_String (Prepared.Action.Executable) = "" then
            declare
               Load : constant Files.File_System.Directory_Load_Result :=
                 Files.File_System.Load_Directory (To_String (Prepared.Path), Settings);
            begin
               if not Load.Success then
                  Files.Model.Set_Error (Model, To_String (Load.Error_Key));
                  return Make_Result (Operation_Failed, To_String (Load.Error_Key), To_String (Prepared.Path));
               end if;

               Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
               Files.Model.Set_Directory_Signature
                 (Model,
                  Files.File_System.Directory_State (To_String (Load.Path)));
               --  Opening a folder records it too: recent folders are useful.
               Files.Model.Note_Recent_Open (Model, To_String (Load.Path));
               Files.Model.Set_Error (Model, "");
               return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
            end;
         elsif not Open_Action_Executable_Is_Available (Prepared.Action) then
            Files.Model.Set_Error (Model, "error.open_action.executable_missing");
            return
              Make_Result
                (Operation_Failed,
                 "error.open_action.executable_missing",
                 To_String (Prepared.Path),
                 Prepared.Action,
                 Attempted => False,
                 Found     => False);
         else
            declare
               Exit_Status : Integer := 0;
               Spawn_OK    : constant Boolean :=
                 Execute_Open_Action
                   (Prepared.Action, Exit_Status, Detach => True);
            begin
               --  Open actions are always detached: the launched application
               --  is fire-and-forget and inherits no Files-side FDs / signal
               --  mask. Spawn_OK reflects whether the wrapper shell ran, not
               --  the application's own exit code.
               if Spawn_OK then
                  --  The opened file joins the recent list.
                  Files.Model.Note_Recent_Open (Model, To_String (Prepared.Path));
                  Files.Model.Set_Error (Model, "");
                  return
                    Make_Result
                      (Operation_Action_Executed,
                       Path   => To_String (Prepared.Path),
                       Action => Prepared.Action,
                       Attempted => True,
                       Found  => True,
                       Exit_Known => False,
                       Exit_Status => Exit_Status);
               end if;

               Files.Model.Set_Error (Model, "error.open_action.execution");
               return
                 Make_Result
                   (Operation_Failed,
                    "error.open_action.execution",
                    To_String (Prepared.Path),
                    Prepared.Action,
                    Attempted => True,
                    Found     => True,
                    Exit_Known => False,
                    Exit_Status => Exit_Status);
            end;
         end if;
      end;
   end Open_Selected;
