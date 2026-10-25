separate (Files_Suite.Interaction)
   procedure Test_Header_Menu_Column_Config (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Model.Context_Menu_Target;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      for Index in 1 .. 6 loop
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "item-" & Index_Image (Index),
               Files.Types.Regular_File_Item, "text/plain"));
      end loop;
      Files.Model.Initialize
        (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root,
         Default_View_Mode => Files.Types.Details);

      --  Right-click the details header, deriving the coordinate from the real
      --  header hit-test (rule a) and driving the real Apply_Right_Click (rule d).
      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Rows     : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         Row      : Files.Rendering.Item_Layout;
         Header_X : Natural := 0;
         Header_Y : Natural := 0;
         In_Main  : Boolean;
      begin
         for Cell of Rows loop
            if Cell.Visible_Index = 1 then
               Row := Cell;
            end if;
         end loop;
         Header_X := Row.Name_X + Row.Name_Width / 2;
         Header_Y := (Layout.Main_Y + Row.Y) / 2;
         Assert
           (Files.Rendering.Hit.Details_Header_Cell_At
              (Snapshot, Layout, Header_X, Header_Y, Line).Present,
            "the derived coordinate lands on the details header band");
         In_Main :=
           Header_X >= Layout.Main_X and then Header_X < Layout.Main_X + Layout.Main_Width
           and then Header_Y >= Layout.Main_Y and then Header_Y < Layout.Main_Y + Layout.Main_Height;
         Files.Interaction.Apply_Right_Click
           (Model, Settings, In_Main, 0, Header_X, Header_Y, Result,
            In_Details_Header => True);
      end;

      Assert (Files.Model.Context_Menu_Is_Open (Model), "the header menu opens on the column header");
      Assert
        (Files.Model.Context_Menu_Target_Of (Model) = Files.Model.Context_Menu_Header,
         "the right-click targets the details-header menu");

      --  Every column toggle and the grouping cycle are offered (rule a).
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Modified_Command),
              "the header menu lists the modified-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Size_Command),
              "the header menu lists the size-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Type_Command),
              "the header menu lists the type-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Created_Command),
              "the header menu lists the created-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Column_Permissions_Command),
              "the header menu lists the permissions-column toggle");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Cycle_Group_By_Command),
              "the header menu lists the grouping cycle");

      --  The item-only commands must not leak into the header menu.
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Open_Selected_Items_Command),
              "the header menu omits Open");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Copy_Selected_Items_Command),
              "the header menu omits Copy");

      --  Selecting a toggle flips the persisted setting through the reducer.
      declare
         Before : constant Boolean := Settings.Column_Visible (Files.Types.Size_Column);
      begin
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Toggle_Column_Size_Command, Result, Found);
         Assert (Found, "the header menu offers the size-column toggle for dispatch");
         Assert (Result.Settings_Changed, "toggling a column reports a persisted settings change");
         Assert
           (Settings.Column_Visible (Files.Types.Size_Column) /= Before,
            "dispatching the toggle flips the column's visibility setting");
         Assert (not Files.Model.Context_Menu_Is_Open (Model), "dispatching a menu row closes the menu");
      end;
   end Test_Header_Menu_Column_Config;
