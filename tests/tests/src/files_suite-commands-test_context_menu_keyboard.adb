separate (Files_Suite.Commands)
   procedure Test_Context_Menu_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Commands.Context_Menu_Row_Kind;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
      Shift    : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Reset_Root;
      Items.Append (Files.File_System.Make_Item (Root, "a.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Root, Items, Root);

      --  The Menu key opens the context menu; Escape closes it again.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Menu);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "the Menu key opens the context menu");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Context_Menu_Is_Open (Model), "Escape closes the context menu");

      --  Shift+F10 opens the context menu (empty-area, since nothing is selected).
      Shift (Guikit.Input.Shift_Key) := True;
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F10, Shift);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "Shift+F10 opens the context menu");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Context_Menu_Highlight (Model),
         0,
         "the menu opens with no row highlighted");

      --  Arrowing down lands only on enabled command rows, skipping separators and
      --  disabled entries, and always moves forward.
      declare
         Rows : constant Files.Commands.Context_Menu_Rows :=
           Files.Commands.Context_Menu_Rows_For (Files.Model.Context_Menu_Target_Of (Model));
         Previous : Natural := 0;
      begin
         for Step in 1 .. Files.Commands.Max_Context_Menu_Rows loop
            Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
            declare
               Highlight : constant Natural := Files.Model.Context_Menu_Highlight (Model);
            begin
               if Highlight /= Previous then
                  Assert (Highlight > Previous, "Down moves the context-menu highlight forward");
                  Assert
                    (Rows.Rows (Highlight).Kind = Files.Commands.Menu_Command,
                     "the highlight lands on a command row, never a separator");
                  Assert
                    (Files.Commands.Is_Enabled (Rows.Rows (Highlight).Command, Model),
                     "the highlight lands only on an enabled command");
                  Previous := Highlight;
               end if;
            end;
         end loop;
         Assert (Previous > 0, "at least one command row is reachable by keyboard");
      end;

      --  Escape closes it.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Context_Menu_Is_Open (Model), "Escape closes the context menu");
   end Test_Context_Menu_Keyboard;
