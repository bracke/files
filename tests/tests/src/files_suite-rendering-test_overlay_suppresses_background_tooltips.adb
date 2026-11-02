separate (Files_Suite.Rendering)
   --  A root selector opens directly beneath the toolbar.  Hovering the
   --  toolbar button that opened it must not draw that button's tooltip over
   --  the selector; only regions belonging to the active selector survive.
   procedure Test_Overlay_Suppresses_Background_Tooltips
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Snap    : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout  : Guikit.Draw.Layout_Metrics;
      Root    : Root_Selector_Layout;
      Toolbar : Guikit.Layout.Toolbar_Layout;
   begin
      Snap.Root_Selector_Open := True;
      Snap.Root_Selected_Index := 1;
      Snap.Root_Paths.Append (To_Unbounded_String ("/"));
      Snap.Root_Labels.Append (To_Unbounded_String ("Filesystem"));
      Layout  := Calculate_Layout (Snap, 480, 360, 20);
      Root    := Calculate_Root_Selector_Layout (Snap, Layout, 20);
      Toolbar := Guikit.Layout.Calculate_Toolbar_Layout (480);

      declare
         Button_X : constant Natural := Guikit.Layout.Toolbar_Left_Button_X (Toolbar, 0);
         Button_W : constant Natural := Guikit.Layout.Toolbar_Left_Button_Width (Toolbar, 0);
         Frame    : constant Frame_Commands :=
           Build_Frame_Commands
             (Snap,
              480,
              360,
              20,
              Hover_X   => Button_X + Button_W / 2,
              Hover_Y   => Guikit.Layout.Toolbar_Input_Y (20) + 10,
              Has_Hover => True);
      begin
         for Tip of Frame.Tooltips loop
            Assert
              (Tip.Y >= Root.Y,
               "the active root selector retains no tooltip region from the toolbar behind it");
         end loop;
      end;

      --  Every input-owning overlay counts, each on its own. The case names
      --  them all, so a new overlay does not compile here until its flag is
      --  listed -- and then this fails until Any_Overlay_Open lists it too.
      for Overlay in Files.Model.Input_Overlay loop
         declare
            One : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
         begin
            Assert (not Any_Overlay_Open (One), "the sample has no overlay open");
            case Overlay is
               when Files.Model.Settings_Pane_Overlay   => One.Settings_Pane_Open := True;
               when Files.Model.Command_Palette_Overlay => One.Command_Palette_Open := True;
               when Files.Model.Root_Selector_Overlay   => One.Root_Selector_Open := True;
               when Files.Model.Sort_Menu_Overlay       => One.Sort_Menu_Open := True;
               when Files.Model.Context_Menu_Overlay    => One.Context_Menu_Open := True;
               when Files.Model.Label_Picker_Overlay    => One.Label_Picker_Open := True;
               when Files.Model.Quick_Look_Overlay      => One.Quick_Look_Open := True;
               when Files.Model.Tree_Pick_Overlay       => One.Tree_Pick_Active := True;
               when Files.Model.Paste_Conflict_Overlay  => One.Paste_Conflict_Open := True;
               when Files.Model.Paste_Execution_Overlay => One.Paste_Progress_Open := True;
            end case;
            Assert (Any_Overlay_Open (One), Files.Model.Input_Overlay'Image (Overlay) & " hides covered tooltips");
         end;
      end loop;
   end Test_Overlay_Suppresses_Background_Tooltips;
