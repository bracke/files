separate (Files_Suite.Rendering)
   procedure Test_Compact_Breadcrumbs_Stay_In_Field (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width   : constant Natural := 640;
      Snap    : View_Snapshot := Sample_Snapshot (0, Files.Types.Details);
      Toolbar : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width);
      Margin  : constant Natural := 6;
      End_X   : constant Natural :=
        Toolbar.Middle_X + Toolbar.Middle_Width - Natural'Min (Margin, Toolbar.Middle_Width);
   begin
      Snap.Breadcrumb_Segments :=
        Files.Breadcrumbs.Segments ("/home/example/projects/ada/files");
      declare
         Rows : constant Breadcrumb_Segment_Layout_Vectors.Vector :=
           Calculate_Breadcrumb_Layout (Snap, Width, 20);
      begin
         Assert (not Rows.Is_Empty, "a compact path still shows its current directory");
         for Row of Rows loop
            Assert
              (Row.X <= End_X and then Row.Width <= End_X - Row.X,
               "every compact breadcrumb remains inside the path field");
         end loop;
      end;
   end Test_Compact_Breadcrumbs_Stay_In_Field;
