separate (Files_Suite.Operations)
   procedure Test_Permission_Grid_Click (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings     : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Settings_Var : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Sub        : constant String := Join (Root, "perm_dir");
      Width      : constant Natural := 1400;
      Height     : constant Natural := 1000;
      Load       : Files.File_System.Directory_Load_Result;
      Model      : Files.Model.Window_Model;
      Target_Bit : constant Natural := 4;  --  group-write cell
      Mask       : constant Natural := 2 ** (8 - Target_Bit);
      Found_Cell : Boolean := False;
      Cell_X     : Natural := 0;
      Cell_Y     : Natural := 0;
   begin
      if not Files.File_System.Supports_Permissions then
         Files_Suite.Support.Skip ("Test_Permission_Grid_Click", "this host has no POSIX permissions to set");
         return;
      end if;

      Reset_Root;
      Ada.Directories.Create_Path (Sub);
      Assert (Files.File_System.Set_Permissions (Sub, 8#755#).Success, "baseline dir mode 0755");

      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "perm_dir");
      Files.Model.Toggle_Info_Pane (Model);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Frame    : constant Files.Rendering.Frame_Commands :=
           Files.Rendering.Build_Frame_Commands (Snapshot, Width, Height);
      begin
         Assert (Snapshot.Permissions_Editable, "single directory selection is permission-editable");
         for Index in 1 .. Natural (Frame.Permission_Hits.Length) loop
            declare
               Cell : constant Files.Rendering.Permission_Hit_Region :=
                 Frame.Permission_Hits.Element (Positive (Index));
            begin
               if Cell.Bit = Target_Bit then
                  Found_Cell := True;
                  Cell_X := Cell.X + Cell.Width / 2;
                  Cell_Y := Cell.Y + Cell.Height / 2;
               end if;
            end;
         end loop;
      end;

      Assert (Found_Cell, "the group-write permission cell has a hit region");

      declare
         Before : constant Natural := Mode_Of (Sub);
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Action : constant Files.Events.Input_Action :=
           Files_Suite.Support.Click_Action (Snapshot, Cell_X, Cell_Y, Width, Height);
         Result : Files.Interaction.Interaction_Result;
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.Permission_Toggle_Input_Action,
            "clicking a permission cell yields a permission-toggle action");
         Files_Suite.Support.Assert_Equal
           (Action.Item_Index,
            Target_Bit,
            "the toggle action carries the clicked cell bit");

         --  A delayed click from a pane that has since closed must not chmod
         --  whichever item happens to be selected when it is reduced.
         Files.Model.Toggle_Info_Pane (Model);
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings_Var,
            Settings_Path     => "",
            Action            => Action,
            Current_Font_Size => 16,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);
         Files_Suite.Support.Assert_Equal
           (Mode_Of (Sub),
            Before,
            "a stale permission action is inert after the info pane closes");

         Files.Model.Toggle_Info_Pane (Model);
         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings_Var,
            Settings_Path     => "",
            Action            =>
              (Kind       => Files.Events.Permission_Toggle_Input_Action,
               Item_Index => 9,
               others     => <>),
            Current_Font_Size => 16,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);
         Files_Suite.Support.Assert_Equal
           (Mode_Of (Sub),
            Before,
            "an invalid permission-bit payload does not change the mode");

         Files.Interaction.Apply_Input_Action
           (Model             => Model,
            Settings          => Settings_Var,
            Settings_Path     => "",
            Action            => Action,
            Current_Font_Size => 16,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);

         Assert
           ((Mode_Of (Sub) / Mask) mod 2 /= (Before / Mask) mod 2,
            "the clicked permission bit is toggled after the reducer applies the action");
      end;
   end Test_Permission_Grid_Click;
