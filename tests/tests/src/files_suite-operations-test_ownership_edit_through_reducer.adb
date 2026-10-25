separate (Files_Suite.Operations)
   procedure Test_Ownership_Edit_Through_Reducer (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Settings_Var : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Target       : constant String := Join (Root, "reducer_own.txt");
      Width        : constant Natural := 1400;
      Height       : constant Natural := 1000;
      Load         : Files.File_System.Directory_Load_Result;
      Model        : Files.Model.Window_Model;
      Uid, Gid     : Files.Types.Account_Id := 0;
      Avail        : Boolean := False;
      Found_Owner  : Boolean := False;
      Owner_X      : Natural := 0;
      Owner_Y      : Natural := 0;
   begin
      if not Files.File_System.Supports_Ownership then
         Files_Suite.Support.Skip ("Test_Ownership_Edit_Through_Reducer", "not Files.File_System.Supports_Ownership");
         return;
      end if;

      Reset_Root;
      Write_File (Target, "reduce me");
      Files.File_System.Ownership_Of (Target, Uid, Gid, Avail);
      Assert (Avail, "ownership of the temp file is readable");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "reducer_own.txt");
      Files.Model.Toggle_Info_Pane (Model);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width, Height);
      begin
         Assert (Snapshot.Ownership_Editable, "single non-trash selection is ownership-editable");
         for Index in 1 .. Natural (Frame.Ownership_Hits.Length) loop
            declare
               Cell : constant Files.Rendering.Ownership_Hit_Region :=
                 Frame.Ownership_Hits.Element (Positive (Index));
            begin
               if not Cell.Is_Group then
                  Found_Owner := True;
                  Owner_X := Cell.X + Cell.Width / 2;
                  Owner_Y := Cell.Y + Cell.Height / 2;
               end if;
            end;
         end loop;
      end;

      Assert (Found_Owner, "the owner value has a click hit region");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Action : constant Files.Events.Input_Action :=
           Files_Suite.Support.Click_Action (Snapshot, Owner_X, Owner_Y, Width, Height);
         Reduce : Files.Interaction.Interaction_Result;
         Routed : Files.Controller.Controller_Result;
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Ownership_Edit_Input_Action,
            "clicking the owner value yields an ownership-edit action");
         Files_Suite.Support.Assert_Equal (Action.Item_Index, 0, "the owner action targets the owner (not group)");

         Files.Model.Toggle_Info_Pane (Model);
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings_Var,
            Settings_Path     => "",
            Action            => Action,
            Current_Font_Size => 16,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Reduce);
         Assert
           (Files.Model.Focus (Model) /= Files.Types.Focus_Ownership_Input,
            "a stale ownership action cannot focus an editor in a closed pane");

         Files.Model.Toggle_Info_Pane (Model);
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings_Var,
            Settings_Path     => "",
            Action            =>
              (Kind       => Files.Events.Ownership_Edit_Input_Action,
               Item_Index => 2,
               others     => <>),
            Current_Font_Size => 16,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Reduce);
         Assert
           (Files.Model.Focus (Model) /= Files.Types.Focus_Ownership_Input,
            "an invalid ownership target does not focus the editor");

         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings_Var,
            Settings_Path     => "",
            Action            => Action,
            Current_Font_Size => 16,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Reduce);

         Files_Suite.Support.Assert_Equal

           (Files.Model.Focus (Model),

            Files.Types.Focus_Ownership_Input,

            "the reducer focuses the ownership editor");

         --  Type the file's own numeric uid (a bare number is accepted as an
         --  id) and commit with Enter through the controller.
         Files.Controller.Replace_Focused_Text
           (Model, Files.Types.Account_Image (Uid));
         Routed := Files.Controller.Handle_Key (Model, Settings_Var, Guikit.Input.Key_Return);

         Files_Suite.Support.Assert_Equal

           (Routed.Operation.Status,

            Files.Operations.Operation_Success,

            "committing the identity ownership edit through the reducer seam succeeds");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Focus (Model),
            Files.Types.Focus_None,
            "committing the ownership edit clears the editor focus");
      end;
   end Test_Ownership_Edit_Through_Reducer;
