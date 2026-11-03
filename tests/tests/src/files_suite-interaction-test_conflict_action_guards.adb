separate (Files_Suite.Interaction)
   procedure Test_Conflict_Action_Guards
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Items    : Files.Paste.Work_Item_Vectors.Vector;
      Existing : Files.Types.String_Vectors.Vector;

      function Click (Button : Files.Events.Conflict_Button_Kind) return Files.Events.Input_Action is
        (Kind            => Files.Events.Conflict_Click_Input_Action,
         Conflict_Button => Button,
         others          => <>);

      procedure Apply (Button : Files.Events.Conflict_Button_Kind) is
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "", Click (Button), Base_Font,
            Guikit.Input.No_Modifiers, Result);
      end Apply;
   begin
      --  A queued event from a dialog that has already closed is inert.
      declare
         Revision : constant Natural := Files.Model.Revision (Model);
      begin
         Apply (Files.Events.Conflict_Button_Apply_All);
         Assert
           (Files.Model.Revision (Model) = Revision
            and then not Files.Model.Paste_Conflict_Apply_All (Model),
            "a stale apply-all click does not mutate hidden conflict state");
      end;

      declare
         Revision : constant Natural := Files.Model.Revision (Model);
      begin
         Files.Interaction.Apply_Input_Action
           (Model, Settings, "",
            (Kind => Files.Events.Paste_Cancel_Input_Action, others => <>),
            Base_Font, Guikit.Input.No_Modifiers, Result);
         Assert
           (Files.Model.Revision (Model) = Revision,
            "a stale paste-cancel action is inert when no paste is active");
      end;

      Items.Append
        (Files.Paste.Work_Item'
           (Source_Path => Ada.Strings.Unbounded.To_Unbounded_String ("/src/a.txt"),
            Dest_Dir    => Ada.Strings.Unbounded.To_Unbounded_String ("/dest"),
            Dest_Name   => Ada.Strings.Unbounded.To_Unbounded_String ("a.txt")));
      Existing.Append
        (Ada.Strings.Unbounded.To_Unbounded_String (Files.Paste.Desired_Path ("/dest", "a.txt")));
      Files.Model.Begin_Paste_Conflict
        (Model, Items, Existing, Files.File_System.Drop_Copy, 1);

      --  The button is typed now, so no unknown value can be sent; an action
      --  naming no button must still not take the destructive fallback path
      --  and cancel the transfer.
      declare
         Revision : constant Natural := Files.Model.Revision (Model);
      begin
         Apply (Files.Events.No_Conflict_Button);
         Assert
           (Files.Model.Paste_Conflict_Is_Active (Model)
            and then Files.Model.Revision (Model) = Revision,
            "no conflict button leaves the active dialog untouched");
      end;

      Apply (Files.Events.Conflict_Button_Apply_All);
      Assert
        (Files.Model.Paste_Conflict_Is_Active (Model)
         and then Files.Model.Paste_Conflict_Apply_All (Model),
         "the valid apply-all control still toggles the active dialog");

      Apply (Files.Events.Conflict_Button_Cancel);
      Assert
        (not Files.Model.Paste_Conflict_Is_Active (Model),
         "the explicit cancel control still closes the conflict dialog");
   end Test_Conflict_Action_Guards;
