with Files.Model.Testing;
with Files.Model.Context_Menu;
with Files.Model.Label_Picker;
with Files.Model.Quick_Look;
with Files.Model.Settings_Pane;
with Files.Model.Tree_Panel;
separate (Files_Suite.Interaction)
   procedure Test_Right_Click_Opens_Menu (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      X, Y     : Natural;
      Found    : Boolean;

      --  Recompute In_Main / Item_Index from the live layout, as the shell does
      --  before calling Apply_Right_Click.
      procedure Right_Click (Target : Positive) is
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Window_W, Window_H, Line);
         Items    : constant Files.Rendering.Item_Layout_Vectors.Vector :=
           Files.Rendering.Calculate_Item_Layout (Snapshot, Layout, Line);
         In_Main  : Boolean;
         Index    : Natural;
      begin
         Item_Center (Model, Target, X, Y, Found);
         In_Main :=
           X >= Layout.Main_X and then X < Layout.Main_X + Layout.Main_Width
           and then Y >= Layout.Main_Y and then Y < Layout.Main_Y + Layout.Main_Height;
         Index := Files.Rendering.Hit.Item_At (Items, X, Y);
         Files.Interaction.Apply_Right_Click
           (Model      => Model,
            Settings   => Settings,
            In_Main    => In_Main,
            Item_Index => Index,
            X          => X,
            Y          => Y,
            Result     => Result);
      end Right_Click;

      procedure Assert_Right_Click_Suppressed (Overlay_Name : String) is
      begin
         Right_Click (2);
         Assert
           (not Files.Model.Context_Menu.Is_Open (Model),
            "right-click behind " & Overlay_Name & " leaves the context menu closed");
      end Assert_Right_Click_Suppressed;
   begin
      Result.Settings_Changed := True;
      Result.Font_Size_Changed := True;
      Result.Needs_Glyph_Rebuild := True;
      Result.Clear_Pending_Text := True;
      Right_Click (2);
      Assert (Found, "a layout cell exists for the right-clicked item");
      Assert (Files.Model.Context_Menu.Is_Open (Model), "right-click opens the context menu");
      Assert (Files.Model.Is_Selected (Model, 2), "right-click selects the unselected item under the cursor");
      Assert
        (not Result.Settings_Changed,
         "right-click clears follow-up flags left by an earlier interaction (settings changed)");
      Assert
        (not Result.Font_Size_Changed,
         "right-click clears follow-up flags left by an earlier interaction (font size changed)");
      Assert
        (not Result.Needs_Glyph_Rebuild,
         "right-click clears follow-up flags left by an earlier interaction (needs glyph rebuild)");
      Assert
        (not Result.Clear_Pending_Text,
         "right-click clears follow-up flags left by an earlier interaction (clear pending text)");

      --  With that menu still open, a right-click on another, unselected
      --  item moves the menu there and selects that item alone.
      Right_Click (3);
      Assert (Files.Model.Context_Menu.Is_Open (Model), "a second right-click opens the menu again");
      Assert (Files.Model.Is_Selected (Model, 3), "it selects the newly right-clicked item");
      Assert (not Files.Model.Is_Selected (Model, 2), "and only that item");
      Right_Click (2);

      --  A queued click can carry an index from an older layout. It must not
      --  open an item menu whose commands would act on the current selection.
      Files.Interaction.Apply_Right_Click
        (Model      => Model,
         Settings   => Settings,
         In_Main    => True,
         Item_Index => Files.Model.Visible_Count (Model) + 1,
         X          => X,
         Y          => Y,
         Result     => Result);
      Assert
        (not Files.Model.Context_Menu.Is_Open (Model),
         "a stale right-click item index leaves the context menu closed");
      Assert
        (Files.Model.Is_Selected (Model, 2),
         "a stale right-click item index preserves the current selection");

      --  With a modal overlay open the same right-click must be swallowed: the
      --  menu stays closed (the shell suppresses it behind modals).
      Files.Model.Context_Menu.Close (Model);
      Files.Model.Settings_Pane.Toggle (Model);
      Assert (Files.Model.Settings_Pane.Is_Open (Model), "settings overlay is open for the suppression case");
      Assert_Right_Click_Suppressed ("Settings");
      Files.Model.Settings_Pane.Toggle (Model);

      Files.Model.Label_Picker.Open (Model);
      Assert_Right_Click_Suppressed ("the label picker");
      Files.Model.Label_Picker.Close (Model);

      Files.Model.Quick_Look.Toggle (Model);
      Assert (Files.Model.Quick_Look.Is_Open (Model), "Quick Look opens for right-click suppression");
      Assert_Right_Click_Suppressed ("Quick Look");
      Files.Model.Quick_Look.Close (Model);

      declare
         Sources : Files.Types.String_Vectors.Vector;
      begin
         Sources.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/tmp/source"));
         Files.Model.Tree_Panel.Begin_Pick (Model, Files.Model.Pick_Copy, Sources, "");
         Files.Model.Tree_Panel.Open (Model);
         Assert_Right_Click_Suppressed ("the destination picker");
         Files.Model.Testing.Clear_Tree_Pick (Model);
         Files.Model.Tree_Panel.Close (Model);
      end;
   end Test_Right_Click_Opens_Menu;
