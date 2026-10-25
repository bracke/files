separate (Files_Suite.Interaction)
   procedure Test_Scroll_Targets_Pane_Under_Cursor (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Info_X, Info_Y : Natural;
      Main_X, Main_Y : Natural;
   begin
      Open_Targeted_Scroll_Fixture (Model);
      Assert (Files.Model.Info_Pane_Is_Open (Model), "the info pane is open for the scroll-target test");

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Layout   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Snapshot, Target_W, Target_H, Line);
         Info     : constant Files.Rendering.Info_Pane_Layout :=
           Files.Rendering.Calculate_Info_Pane_Layout (Snapshot, Layout, Line);
         Main     : constant Files.Rendering.Main_View_Layout :=
           Files.Rendering.Calculate_Main_View_Layout (Snapshot, Layout, Line);
      begin
         Assert (Info.Width > 0 and then Info.Height > 0, "the info pane has a hittable region");
         Assert
           (Info.Scrollbar_Visible and then Main.Scrollbar_Visible,
            "the compact targeted-scroll fixture overflows both scrollable panes");
         Info_X := Info.X + Info.Width / 2;
         Info_Y := Info.Y + Info.Height / 2;
         Main_X := Layout.Main_X + Layout.Main_Width / 2;
         Main_Y := Layout.Main_Y + Layout.Main_Height / 2;

         declare
            Info_Max : constant Natural :=
              1 + (Info.Content_Height - Info.Height - 1) / Line;
            Main_Max : constant Natural :=
              1
              + (Main.Content_Height - Main.Scrollbar_Track_Height - 1) / Line;
            At_End : Files.Rendering.View_Snapshot := Snapshot;
         begin
            At_End.Info_Pane_Scroll_Lines := Info_Max;
            At_End.Main_View_Scroll_Lines := Main_Max;
            Assert
              (Files.Events.Translate_Scroll_At
                 (At_End, Info_X, Info_Y, Target_W, Target_H,
                  Y_Offset => -1, Line_Height => Line).Kind
                 = Files.Events.No_Input_Action,
               "the info pane does not accumulate wheel input beyond its final page");
            Assert
              (Files.Events.Translate_Scroll_At
                 (At_End, Main_X, Main_Y, Target_W, Target_H,
                  Y_Offset => -1, Line_Height => Line).Kind
                 = Files.Events.No_Input_Action,
               "the main view does not accumulate wheel input beyond its final page");
         end;
      end;

      Scroll_Down_At (Model, Settings, Info_X, Info_Y);
      Assert
        (Files.Model.Info_Pane_Scroll_Lines (Model) > 0,
         "scrolling over the info pane moves the info-pane offset");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model),
         0,
         "scrolling over the info pane leaves the main view untouched");

      declare
         Info_Before : constant Natural := Files.Model.Info_Pane_Scroll_Lines (Model);
      begin
         Scroll_Down_At (Model, Settings, Main_X, Main_Y);
         Assert
           (Files.Model.Main_View_Scroll_Lines (Model) > 0,
            "scrolling over the main view moves the main-view offset");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Info_Pane_Scroll_Lines (Model),
            Info_Before,
            "scrolling over the main view leaves the info-pane offset unchanged");
      end;

      Files.Model.Set_Main_View_Scroll_Lines (Model, 0);
      declare
         Fits   : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Wide   : constant Files.Rendering.Layout_Metrics :=
           Files.Rendering.Calculate_Layout (Fits, Window_W, Window_H, Line);
         Action : constant Files.Events.Input_Action :=
           Files.Events.Translate_Scroll_At
             (Fits,
              Wide.Main_X + Wide.Main_Width / 2,
              Wide.Main_Y + Wide.Main_Height / 2,
              Window_W, Window_H, Y_Offset => -1, Line_Height => Line);
      begin
         Files_Suite.Support.Assert_Equal
           (Action.Kind,
            Files.Events.No_Input_Action,
            "wheel input is inert when the entire main view already fits");
      end;
   end Test_Scroll_Targets_Pane_Under_Cursor;
