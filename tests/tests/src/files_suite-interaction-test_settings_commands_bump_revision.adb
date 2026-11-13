separate (Files_Suite.Interaction)
   --  Every way a window changes its settings bumps its settings revision
   --  (Files.Model.Settings_Revision): the cross-window sync shares only what
   --  the revision shows, so a change that skipped it would stay in one
   --  window. Each change runs through the dispatch the shell uses, on a
   --  fresh window.
   procedure Test_Settings_Commands_Bump_Revision (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      type Settings_Change is
        (Toggle_Hidden, Settings_Pane_Save, Zoom_In, Zoom_Out, Zoom_Reset, Column_Resize, Sort_Change);

      Path : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "revision.conf");

      procedure Check (Change : Settings_Change) is
         Model    : Files.Model.Window_Model;
         Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
         Result   : Files.Interaction.Interaction_Result;
         Items    : Files.Items.Item_Vectors.Vector;
         Before   : Natural;

         procedure Run (Command : Files.Commands.Command_Id) is
         begin
            Files.Interaction.Execute_Command (Model, Settings, Path, Command, Result => Result);
         end Run;

         procedure Press (Key : Guikit.Input.Key_Code) is
         begin
            Files.Interaction.Handle_Key
              (Model         => Model,
               Settings      => Settings,
               Settings_Path => Path,
               Key           => Key,
               Modifiers     => Ctrl,
               Result        => Result);
         end Press;
      begin
         Files_Suite.Support.Reset_Root;
         Files_Suite.Support.Write_File (Files_Suite.Support.Join (Files_Suite.Support.Root, "Alpha.txt"));
         Files_Suite.Support.Write_File (Files_Suite.Support.Join (Files_Suite.Support.Root, "Beta.txt"));
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "Beta.txt", Files.Types.Regular_File_Item, "text/plain"));
         Files.Model.Initialize
           (Model,
            Directory_Path => Files_Suite.Support.Root,
            Items          => Items,
            Home_Path      => "/home/test");

         --  What the change needs set up first does not count.
         case Change is
            when Settings_Pane_Save =>
               Run (Files.Commands.Toggle_Settings_Pane_Command);
               Assert (Files.Model.Settings_Pane_Is_Open (Model), "the settings pane opens for the save case");
               declare
                  Edited : Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);
               begin
                  Edited.Scalars (Files.Settings.Default_View_Mode_Setting) :=
                    Ada.Strings.Unbounded.To_Unbounded_String ("details");
                  Files.Model.Set_Settings_Draft (Model, Edited);
               end;
            when Zoom_Reset =>
               Settings.Font_Pixel_Size := Files.Settings.Default_Font_Pixel_Size + 4;
            when others =>
               null;
         end case;

         Before := Files.Model.Settings_Revision (Model);
         case Change is
            when Toggle_Hidden =>
               Run (Files.Commands.Toggle_Hidden_Files_Command);
            when Settings_Pane_Save =>
               Run (Files.Commands.Save_Settings_Command);
            when Zoom_In =>
               Press (Guikit.Input.Key_Equal);
            when Zoom_Out =>
               Press (Guikit.Input.Key_Minus);
            when Zoom_Reset =>
               Press (Guikit.Input.Key_0);
            when Column_Resize =>
               Files.Interaction.Apply_Column_Resize
                 (Model, Settings, Files.Types.Size_Column,
                  Origin_X     => 500,
                  Origin_Width => 300,
                  Current_X    => 423,
                  Result       => Result,
                  Line_Height  => Line);
            when Sort_Change =>
               Files.Interaction.Apply_Input_Action
                 (Model         => Model,
                  Settings      => Settings,
                  Settings_Path => Path,
                  Action        =>
                    (Kind => Files.Events.Command_Input_Action, Command => Files.Commands.Sort_By_Size_Command),
                  Modifiers     => Guikit.Input.No_Modifiers,
                  Result        => Result);
         end case;

         Assert (Result.Settings_Changed, Settings_Change'Image (Change) & " reports a settings change");
         Assert (Files.Model.Settings_Revision (Model) > Before,
                 Settings_Change'Image (Change) & " bumps the window's settings revision");
      end Check;
   begin
      for Change in Settings_Change loop
         Check (Change);
      end loop;
   end Test_Settings_Commands_Bump_Revision;
