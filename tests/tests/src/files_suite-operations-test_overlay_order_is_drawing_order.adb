separate (Files_Suite.Operations)
   --  One order of overlays: the one drawn on top owns the input and is the
   --  one Escape closes; Escape does not reach past one with its own way out.
   procedure Test_Overlay_Order_Is_Drawing_Order (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Model.Input_Overlay;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Overlay  : Files.Model.Input_Overlay;
      Item     : constant String := Join (Root, "look.txt");
   begin
      Reset_Root;
      Write_File (Item, "look");
      Files.Model.Initialize (Model, Root, Files.File_System.Load_Directory (Root, Settings).Items, Root);
      Assert (Files.Model.Select_By_Name (Model, "look.txt"), "an item to look at");
      Files.Model.Open_Quick_Look (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selected_Item (Model)));
      Assert (Files.Model.Topmost_Overlay (Model, Overlay) and then Overlay = Files.Model.Quick_Look_Overlay,
              "Quick Look alone is on top");
      Assert (not Files.Model.Escape_Overlay (Model, Overlay), "Escape's close command does not reach below it");

      Files.Model.Open_Command_Palette (Model);
      Assert (Files.Model.Topmost_Overlay (Model, Overlay) and then Overlay = Files.Model.Command_Palette_Overlay,
              "the palette, drawn over Quick Look, is on top of it");
      Assert (Files.Model.Escape_Overlay (Model, Overlay) and then Overlay = Files.Model.Command_Palette_Overlay,
              "and Escape closes it first");
      Assert (Files.Model.Window_Overlay_Shown (Model, Files.Model.Command_Palette_Overlay),
              "the window layer draws it");
      --  The pane under the palette is not drawn, and the frame leaves no
      --  hole for it.
      Files.Model.Begin_Settings_Edit (Model, Files.Settings.Make_Draft (Settings));
      Files.Model.Open_Command_Palette (Model);
      Assert (Files.Model.Settings_Pane_Is_Open (Model) and then Files.Model.Command_Palette_Is_Open (Model),
              "the palette is opened over the settings pane");
      Assert (not Files.Rendering.Build_Snapshot (Model, Settings).Settings_Pane_Open,
              "a settings pane under the palette is not in the drawn snapshot");
      Assert (Files.Rendering.Build_Snapshot (Model, Settings).Command_Palette_Open, "the palette is");
      Files.Model.Close_Overlay (Model, Overlay);
      Assert (Files.Model.Quick_Look_Is_Open (Model), "Quick Look is still open below");
      Reset_Root;
   end Test_Overlay_Order_Is_Drawing_Order;
