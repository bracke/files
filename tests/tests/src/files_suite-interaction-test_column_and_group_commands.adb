separate (Files_Suite.Interaction)
   procedure Test_Column_And_Group_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Group_Mode;
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Before   : constant Boolean :=
        Settings.Column_Visible (Files.Types.Permissions_Column);
   begin
      --  The toggle command flips the persisted visibility and reports the
      --  settings change through the interaction result.
      Files.Interaction.Execute_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Command           => Files.Commands.Toggle_Column_Permissions_Command,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Assert (Settings.Column_Visible (Files.Types.Permissions_Column) /= Before,
              "the permissions-column command flips its visibility");
      Assert (Result.Settings_Changed, "the column toggle reports a settings change");

      --  The controller applies a settings command itself when given the
      --  settings to change; the interaction layer only adds UI follow-ups.
      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Execute_Command
             (Files.Commands.Toggle_Column_Permissions_Command, Model, Settings, Settings_Path => "");
      begin
         Files_Suite.Support.Assert_Equal
           (Outcome.Status,
            Files.Controller.Controller_Command_Executed,
            "the controller executes a settings command");
         Files_Suite.Support.Assert_Equal
           (Settings.Column_Visible (Files.Types.Permissions_Column),
            Before,
            "the controller applies the settings command to the settings it is given");
      end;

      --  The group command advances the persisted grouping mode.
      Result.Font_Size_Changed := True;
      Result.Needs_Glyph_Rebuild := True;
      Result.Directory_Reloaded := True;
      Result.Clear_Pending_Text := True;
      Result.Context_Menu_Changed := True;
      Files.Interaction.Execute_Command
        (Model             => Model,
         Settings          => Settings,
         Settings_Path     => "",
         Command           => Files.Commands.Cycle_Group_By_Command,
         Current_Font_Size => Base_Font,
         Result            => Result);
      Files_Suite.Support.Assert_Equal
        (Settings.Group_By,
         Files.Types.Group_By_Type,
         "the group-by command advances the grouping mode");
      Assert
        (not Result.Font_Size_Changed,
         "direct command execution clears unrelated follow-up flags (font size changed)");
      Assert
        (not Result.Needs_Glyph_Rebuild,
         "direct command execution clears unrelated follow-up flags (needs glyph rebuild)");
      Assert
        (not Result.Directory_Reloaded,
         "direct command execution clears unrelated follow-up flags (directory reloaded)");
      Assert
        (not Result.Clear_Pending_Text,
         "direct command execution clears unrelated follow-up flags (clear pending text)");
      Assert
        (not Result.Context_Menu_Changed,
         "direct command execution clears unrelated follow-up flags (context menu changed)");

      --  With grouping active in the details view, Build_Snapshot inserts a
      --  non-selectable header row (Visible_Index zero) ahead of the items.
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Header_Rows : Natural := 0;
         Item_Rows   : Natural := 0;
      begin
         for Item of Snapshot.Items loop
            if Item.Is_Group_Header then
               Header_Rows := Header_Rows + 1;
               Files_Suite.Support.Assert_Equal (Item.Visible_Index, 0, "a group header carries no visible index");
            else
               Item_Rows := Item_Rows + 1;
               Assert (Item.Visible_Index > 0, "a real row keeps its visible index");
            end if;
         end loop;
         Assert (Header_Rows >= 1, "grouping inserts at least one header row");
         Files_Suite.Support.Assert_Equal (Item_Rows, 3, "every sample item survives grouping");
      end;
   end Test_Column_And_Group_Commands;
