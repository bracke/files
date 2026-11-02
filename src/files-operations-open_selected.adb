with Ada.Containers.Vectors;

separate (Files.Operations)
function Open_Selected
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
   return Operation_Result
is
   Items : constant Files.Items.Item_Vectors.Vector := Files.Model.Selected_Items (Model);
   package Action_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Files.Settings.Open_Action, "=" => Files.Settings."=");
begin
   if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then
      return Disabled (Model, "error.selection.empty");
   elsif Natural (Items.Length) > 1 then
      declare
         --  The checks every item must pass (no folder, an action for its
         --  type, no unsafe placeholder) are Prepare's, which also reports
         --  the first refusal.
         Prepared : constant Operation_Result := Prepare_Open_Selected_Action (Model, Settings, Modifiers);
         Actions  : Action_Vectors.Vector;
         First_Exit_Status : Integer := 0;
      begin
         if Prepared.Status /= Operation_Success then
            return Prepared;
         end if;

         --  Every executable is checked before any is started.
         for Item of Items loop
            declare
               Action : constant Files.Settings.Open_Action :=
                 Files.Settings.Expand_Placeholders
                   (Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers).Action,
                    To_String (Item.Full_Path));
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
               Actions.Append (Action);
            end;
         end loop;

         for Index in Items.First_Index .. Items.Last_Index loop
            declare
               Path        : constant String := To_String (Items (Index).Full_Path);
               Exit_Status : Integer := 0;
               Spawn_OK    : constant Boolean :=
                 Execute_Open_Action (Actions (Index), Exit_Status, Detach => True);
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
                       Path,
                       Actions (Index),
                       Attempted => True,
                       Found     => True,
                       Exit_Known => False,
                       Exit_Status => Exit_Status);
               end if;

               --  Each launched file joins the recent list, freshest last.
               Files.Model.Note_Recent_Open (Model, Path);
               if Index = Items.First_Index then
                  First_Exit_Status := Exit_Status;
               end if;
            end;
         end loop;

         Files.Model.Set_Error (Model, "");
         return
           Make_Result
             (Operation_Action_Executed,
              Path      => To_String (Prepared.Path),
              Action    => Prepared.Action,
              Attempted => True,
              Found     => True,
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
              Files.File_System.Load_Directory_Deferring_Thumbnails (To_String (Prepared.Path), Settings);
         begin
            if not Load.Success then
               Files.Model.Set_Error (Model, To_String (Load.Error_Key));
               return Make_Result (Operation_Failed, To_String (Load.Error_Key), To_String (Prepared.Path));
            end if;

            Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
            Settle_Current_Is_Trash (Model);
            Files.Model.Set_Directory_Signature
              (Model,
               Files.File_System.Directory_State (To_String (Load.Path)));
            --  Opening a folder records it too: recent folders are useful.
            Files.Model.Note_Recent_Open (Model, To_String (Load.Path));
            Files.Model.Set_Error (Model, "");
            --  Last, once the listing it refreshes is the current one.
            Support.Generate_Missing_Thumbnails (Model, Settings, Load.Items);
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
