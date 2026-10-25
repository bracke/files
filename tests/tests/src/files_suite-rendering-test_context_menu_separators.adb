separate (Files_Suite.Rendering)
   procedure Test_Context_Menu_Separators (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snapshot : View_Snapshot := Sample_Snapshot (6, Files.Types.Small_Icons);

      --  The full set of real commands the item menu must still offer, in any
      --  order, regardless of the separators woven between the groups.
      Expected : constant array (1 .. 19) of Files.Commands.Command_Id :=
        [Files.Commands.Open_Selected_Items_Command,
         Files.Commands.Open_With_Command,
         Files.Commands.Open_Containing_Folder_Command,
         Files.Commands.Toggle_Favorite_Command,
         Files.Commands.Set_Color_Label_Command,
         Files.Commands.Copy_Selected_Items_Command,
         Files.Commands.Cut_Selected_Items_Command,
         Files.Commands.Copy_Path_Command,
         Files.Commands.Copy_To_Command,
         Files.Commands.Move_To_Command,
         Files.Commands.Duplicate_Selected_Command,
         Files.Commands.Compress_Zip_Command,
         Files.Commands.Compress_7z_Command,
         Files.Commands.Extract_Archive_Command,
         Files.Commands.Create_Symlink_Command,
         Files.Commands.Create_Hardlink_Command,
         Files.Commands.Rename_Selected_Items_Command,
         Files.Commands.Delete_Selected_Items_Command,
         Files.Commands.Restore_From_Trash_Command];
   begin
      Snapshot.Context_Menu_Open := True;
      Snapshot.Context_Menu_Target := Files.Model.Context_Menu_Item;
      Snapshot.Context_Menu_X := 100;
      Snapshot.Context_Menu_Y := 100;

      declare
         Menu : constant Context_Menu_Layout :=
           Calculate_Context_Menu_Layout (Snapshot, 1000, 800, 20);
         Separator_Count : Natural := 0;
         Command_Count   : Natural := 0;
      begin
         Assert (Menu.Visible, "the item context menu is visible");
         Assert (Menu.Row_Count <= Max_Context_Menu_Rows, "the menu fits its fixed row array");
         Assert
           (Menu.Separator_Height > 0 and then Menu.Separator_Height < Menu.Row_Height,
            "separator rows are shorter than command rows");

         --  Every real command still appears exactly once on a command row.
         for Command of Expected loop
            declare
               Seen : Natural := 0;
            begin
               for Row in 1 .. Menu.Row_Count loop
                  if Menu.Row_Kinds (Row) = Command_Row
                    and then Menu.Commands (Row) = Command
                  then
                     Seen := Seen + 1;
                  end if;
               end loop;
               Files_Suite.Support.Assert_Equal (Seen, 1, "each grouped command appears exactly once");
            end;
         end loop;

         for Row in 1 .. Menu.Row_Count loop
            if Menu.Row_Kinds (Row) = Separator_Row then
               Separator_Count := Separator_Count + 1;
               --  A separator carries no command and is not selectable.
               Files_Suite.Support.Assert_Equal
                 (Menu.Commands (Row),
                  Files.Commands.No_Command,
                  "a separator row carries no command");
               declare
                  Probe_X : constant Natural := Menu.X + Menu.Width / 2;
                  Probe_Y : constant Natural :=
                    Context_Menu_Row_Top (Menu, Row) + Menu.Separator_Height / 2;
               begin
                  Files_Suite.Support.Assert_Equal
                    (Context_Menu_Row_At (Menu, Probe_X, Probe_Y),
                     0,
                     "a hit test on a separator selects no row");
               end;
            else
               Command_Count := Command_Count + 1;
               --  A real command row hit-tests back to its own index.
               declare
                  Probe_X : constant Natural := Menu.X + Menu.Width / 2;
                  Probe_Y : constant Natural :=
                    Context_Menu_Row_Top (Menu, Row) + Menu.Row_Height / 2;
               begin
                  Files_Suite.Support.Assert_Equal
                    (Context_Menu_Row_At (Menu, Probe_X, Probe_Y),
                     Row,
                     "a hit test on a command row returns that row");
               end;
            end if;
         end loop;

         Files_Suite.Support.Assert_Equal

           (Command_Count,

            Expected'Length,

            "all real commands are laid out");
         Files_Suite.Support.Assert_Equal (Separator_Count, 5, "five separators divide the six command groups");

         declare
            Clipped : Context_Menu_Layout := Menu;
            Probe_X : constant Natural := Menu.X + Menu.Width / 2;
            Probe_Y : constant Natural := Menu.Y + Menu.Padding;
         begin
            --  Model the renderer clipping the panel before its first row. The
            --  hit test must honor the declared surface, not the latent rows.
            Clipped.Height := Menu.Padding;
            Files_Suite.Support.Assert_Equal
              (Context_Menu_Row_At (Clipped, Probe_X, Probe_Y),
               0,
               "a row outside the declared context-menu height is not clickable");
         end;
      end;

      --  The complete item menu must remain on-screen and mouse-reachable at
      --  the compact live-smoke height.  It uses two columns, split at a group
      --  boundary, rather than clipping its lower commands.
      declare
         Menu : constant Context_Menu_Layout :=
           Calculate_Context_Menu_Layout (Snapshot, 480, 360, 20);
      begin
         Files_Suite.Support.Assert_Equal (Menu.Column_Count, 2, "the compact item menu uses two columns");
         Assert (Menu.Height <= 360, "the compact item menu stays within the window height");
         Assert
           (Menu.Column_Break_Row > 0 and then Menu.Column_Break_Row < Menu.Row_Count,
            "the compact item menu splits between two non-empty columns");

         for Row in 1 .. Menu.Row_Count loop
            if Menu.Row_Kinds (Row) = Command_Row then
               declare
                  Probe_X : constant Natural :=
                    Context_Menu_Row_Left (Menu, Row) + Context_Menu_Row_Width (Menu, Row) / 2;
                  Probe_Y : constant Natural :=
                    Context_Menu_Row_Top (Menu, Row) + Menu.Row_Height / 2;
               begin
                  Files_Suite.Support.Assert_Equal
                    (Context_Menu_Row_At (Menu, Probe_X, Probe_Y),
                     Row,
                     "every compact-menu command hit-tests in its displayed column");
               end;
            end if;
         end loop;
      end;
   end Test_Context_Menu_Separators;
