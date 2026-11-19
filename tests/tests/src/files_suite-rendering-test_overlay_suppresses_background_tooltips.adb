with Files.Rendering.Testing;
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
      Snap.Roots.Append
        (Root_Row'(Path  => To_Unbounded_String ("/"),
          Label => To_Unbounded_String ("Filesystem")));
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
              Pointer =>
                (Hover_X => Button_X + Button_W / 2,
                 Hover_Y => Guikit.Layout.Toolbar_Input_Y (20) + 10,
                 Has_Hover => True,
                 others => <>));
      begin
         for Tip of Frame.Tooltips loop
            Assert
              (Tip.Y >= Root.Y,
               "the active root selector retains no tooltip region from the toolbar behind it");
         end loop;
      end;

      --  Every input-owning overlay counts, each on its own; with two open,
      --  the one higher in Files.UI_Types.Overlay_Stack is the snapshot's top --
      --  the overlay the model, the keyboard and the pointer take as on top.
      --  The case names them all, so a new overlay does not compile here
      --  until its flag is listed.
      declare
         procedure Open (Snapshot : in out View_Snapshot; Overlay : Files.UI_Types.Input_Overlay) is
         begin
            case Overlay is
               when Files.UI_Types.Settings_Pane_Overlay   => Snapshot.Settings_Pane_Open := True;
               when Files.UI_Types.Command_Palette_Overlay => Snapshot.Command_Palette_Open := True;
               when Files.UI_Types.Root_Selector_Overlay   => Snapshot.Root_Selector_Open := True;
               when Files.UI_Types.Sort_Menu_Overlay       => Snapshot.Sort_Menu_Open := True;
               when Files.UI_Types.Context_Menu_Overlay    => Snapshot.Context_Menu_Open := True;
               when Files.UI_Types.Label_Picker_Overlay    => Snapshot.Label_Picker_Open := True;
               when Files.UI_Types.Quick_Look_Overlay      => Snapshot.Quick_Look.Open := True;
               when Files.UI_Types.Tree_Pick_Overlay       => Snapshot.Tree_Pick_Active := True;
               when Files.UI_Types.Paste_Conflict_Overlay  => Snapshot.Paste_Conflict_Open := True;
               when Files.UI_Types.Foreground_Job_Overlay  => Snapshot.Paste_Progress.Open := True;
            end case;
         end Open;

         use type Files.UI_Types.Input_Overlay;
         Stack : Files.UI_Types.Overlay_Order renames Files.UI_Types.Overlay_Stack;
         Base  : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      begin
         Assert (not Files.Rendering.Testing.Any_Overlay_Open (Base), "the sample has no overlay open");
         Files_Suite.Support.Assert_Equal
           (Files.Rendering.Topmost_Overlay_Position (Base), 0, "no overlay is on top of the sample");
         for Upper in Stack'Range loop
            declare
               One : View_Snapshot := Base;
            begin
               Open (One, Stack (Upper));
               Assert
                 (Files.Rendering.Testing.Any_Overlay_Open (One)
                    and then Files.Rendering.Overlay_Open (One, Stack (Upper)),
                  Files.UI_Types.Input_Overlay'Image (Stack (Upper)) & " hides covered tooltips");
               Files_Suite.Support.Assert_Equal
                 (Files.Rendering.Topmost_Overlay_Position (One), Upper,
                  Files.UI_Types.Input_Overlay'Image (Stack (Upper)) & " alone is on top");
            end;
            for Lower in Upper + 1 .. Stack'Last loop
               declare
                  Two : View_Snapshot := Base;
               begin
                  Open (Two, Stack (Lower));
                  Open (Two, Stack (Upper));
                  Files_Suite.Support.Assert_Equal
                    (Files.Rendering.Topmost_Overlay_Position (Two), Upper,
                     Files.UI_Types.Input_Overlay'Image (Stack (Upper)) & " is above "
                     & Files.UI_Types.Input_Overlay'Image (Stack (Lower)));
               end;
            end loop;
         end loop;
         --  The stack names every overlay exactly once.
         for Overlay in Files.UI_Types.Input_Overlay loop
            Assert
              ((for some Index in Stack'Range => Stack (Index) = Overlay),
               Files.UI_Types.Input_Overlay'Image (Overlay) & " is in the overlay stack");
         end loop;
         Files_Suite.Support.Assert_Equal
           (Integer (Stack'Length), Files.UI_Types.Input_Overlay'Pos (Files.UI_Types.Input_Overlay'Last) + 1,
            "the overlay stack names each overlay once");
      end;
   end Test_Overlay_Suppresses_Background_Tooltips;
