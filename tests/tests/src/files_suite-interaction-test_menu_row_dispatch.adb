separate (Files_Suite.Interaction)
   procedure Test_Menu_Row_Dispatch (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;
      In_Main  : Boolean;
      Index    : Natural;
   begin
      --  Open the item context menu through the real right-click path so the
      --  menu rows come from the live snapshot.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
      begin
         Item_Center (Model, 2, X, Y, Found);
         Assert (Found, "a layout cell exists for the menu-anchor item");
         In_Main :=
           X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
           and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
         Index := Files.Rendering.Hit.Item_At (Items, X, Y);
         Files.Interaction.Apply_Right_Click (Model, Settings, In_Main, Index, X, Y, Result);
      end;
      Assert (Files.Model.Context_Menu_Is_Open (Model), "context menu is open before the row click");

      --  Resolve the Copy row from the real menu layout (rule a) and dispatch it.
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Menu     : constant Files.Rendering.Context_Menu_Layout :=
           Files.Rendering.Calculate_Context_Menu_Layout (Snapshot, Window_W, Window_H, Line);
         Target_Row : Natural := 0;
         Row_X      : Natural;
         Row_Y      : Natural;
      begin
         for Row in 1 .. Menu.Row_Count loop
            if Menu.Commands (Row) = Files.Commands.Copy_Selected_Items_Command then
               Target_Row := Row;
            end if;
         end loop;
         Assert (Target_Row > 0, "the item context menu offers the copy command");

         Row_X := Menu.X + Menu.Width / 2;
         Row_Y :=
           Files.Rendering.Context_Menu_Row_Top (Menu, Target_Row) + Menu.Row_Height / 2;
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Hit.Context_Menu_Row_At (Menu, Row_X, Row_Y),
            Target_Row,
            "the derived coordinate hit-tests back to the copy row");

         Files.Interaction.Apply_Context_Menu_Command
           (Model             => Model,
            Settings          => Settings,
            Settings_Path     => "",
            Command           => Menu.Commands (Target_Row),
            Current_Font_Size => Base_Font,
            Modifiers         => Guikit.Input.No_Modifiers,
            Result            => Result);
      end;

      Files_Suite.Support.Assert_Equal

        (Result.Command,

         Files.Commands.Copy_Selected_Items_Command,

         "the result echoes the dispatched command id");
      Assert (Result.Context_Menu_Changed, "the result reports the menu closing");
      Assert (not Files.Model.Context_Menu_Is_Open (Model), "dispatching a menu row closes the menu");
      Assert
        (Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Copy,
         "the copy command records a copy clipboard intent");
      Assert (Files.Model.Clipboard_Has_Items (Model), "the copy command captured the selected item");

      --  Replaying that row after its menu has closed must not execute it
      --  against whatever selection exists at reduction time.
      Files.Model.Clear_Clipboard (Model);
      Files.Interaction.Apply_Context_Menu_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Command           => Files.Commands.Copy_Selected_Items_Command,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
      Assert
        (not Files.Model.Clipboard_Has_Items (Model),
         "a stale menu-row action is inert after its menu closes (clipboard empty)");
      Assert (not Result.Command_Executed, "a stale menu-row action is inert after its menu closes (command executed)");
      Assert
        (not Result.Context_Menu_Changed,
         "a stale menu-row action is inert after its menu closes (context menu changed)");

      --  A click that misses every menu row still closes the menu and must not
      --  leak follow-up flags from an earlier result stored in the same object.
      Files.Model.Open_Context_Menu (Model, X, Y, Files.Model.Context_Menu_Empty);
      Files.Interaction.Apply_Context_Menu_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Command           => Files.Commands.Copy_Selected_Items_Command,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
      Assert
        (Files.Model.Context_Menu_Is_Open (Model),
         "an item-only command is rejected by the open empty-area menu (menu open)");
      Assert
        (not Files.Model.Clipboard_Has_Items (Model),
         "an item-only command is rejected by the open empty-area menu (clipboard empty)");
      Assert
        (not Result.Command_Executed,
         "an item-only command is rejected by the open empty-area menu (command executed)");
      Assert
        (not Result.Context_Menu_Changed,
         "an item-only command is rejected by the open empty-area menu (context menu changed)");

      Result.Settings_Changed := True;
      Result.Font_Size_Changed := True;
      Result.Needs_Glyph_Rebuild := True;
      Result.Directory_Reloaded := True;
      Result.Clear_Pending_Text := True;
      Files.Interaction.Apply_Context_Menu_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Command           => Files.Commands.No_Command,
         Current_Font_Size => Base_Font,
         Modifiers         => Guikit.Input.No_Modifiers,
         Result            => Result);
      Assert (not Files.Model.Context_Menu_Is_Open (Model), "a missed menu row still closes the menu");
      Assert
        (Result.Context_Menu_Changed,
         "a missed menu row returns only its own context-menu follow-up (context menu changed)");
      Files_Suite.Support.Assert_Equal
        (Result.Command, Files.Commands.No_Command,
         "a missed menu row returns only its own context-menu follow-up (command)");
      Assert
        (not Result.Command_Executed,
         "a missed menu row returns only its own context-menu follow-up (command executed)");
      Assert
        (not Result.Settings_Changed,
         "a missed menu row returns only its own context-menu follow-up (settings changed)");
      Assert
        (not Result.Font_Size_Changed,
         "a missed menu row returns only its own context-menu follow-up (font size changed)");
      Assert
        (not Result.Needs_Glyph_Rebuild,
         "a missed menu row returns only its own context-menu follow-up (needs glyph rebuild)");
      Assert
        (not Result.Directory_Reloaded,
         "a missed menu row returns only its own context-menu follow-up (directory reloaded)");
      Assert
        (not Result.Clear_Pending_Text,
         "a missed menu row returns only its own context-menu follow-up (clear pending text)");

      --  Keyboard open/close routes mutate the same menu state through the
      --  controller and must report the transition through the reducer result.
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_F10, Shift, Base_Font, Result);
      Assert
        (Files.Model.Context_Menu_Is_Open (Model)
         and then Result.Context_Menu_Changed,
         "Shift+F10 reports opening the context menu");
      Files.Interaction.Handle_Key
        (Model, Settings, "", Guikit.Input.Key_Escape,
         Guikit.Input.No_Modifiers, Base_Font, Result);
      Assert
        (not Files.Model.Context_Menu_Is_Open (Model)
         and then Result.Context_Menu_Changed,
         "Escape reports closing the context menu");
   end Test_Menu_Row_Dispatch;
