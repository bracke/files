separate (Files_Suite.Model)
   procedure Test_Group_By_Label_Bands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Header_Count : Natural := 0;
      Alpha_Pos    : Natural := 0;
      Beta_Pos     : Natural := 0;
      Gamma_Pos    : Natural := 0;
      Header_Before_Alpha : Boolean := False;
   begin
      Files.Model.Set_View_Mode (Model, Files.Types.Details);
      Settings.Group_By := Files.Types.Group_By_Label;
      --  Alpha -> Red (band 1), Gamma -> Blue (band 5), Beta stays unlabeled
      --  (band 8, drawn last).
      Files.Settings.Set_Label (Settings, Join (Root, "Alpha.txt"), Files.Types.Red);
      Files.Settings.Set_Label (Settings, Join (Root, "Gamma.md"), Files.Types.Blue);
      --  The window loop does this before every frame.
      Files.Model.Sync_Grouping (Model, Settings);

      declare
         Snapshot : constant Files.Rendering.View_Snapshot :=
           Files.Rendering.Build_Snapshot (Model, Settings);
         Prev_Was_Header : Boolean := False;
         Position : Natural := 0;
         Last_Visible : Natural := 0;
      begin
         for Item of Snapshot.Items loop
            Position := Position + 1;
            if not Item.Is_Group_Header then
               --  Keyboard and range selection walk visible indexes in order;
               --  the drawn rows must follow the same order.
               Files_Suite.Support.Assert_Equal
                 (Item.Visible_Index,
                  Last_Visible + 1,
                  "grouped rows are drawn in the order the keyboard walks them");
               Last_Visible := Item.Visible_Index;
            end if;
            if Item.Is_Group_Header then
               Header_Count := Header_Count + 1;
               Files_Suite.Support.Assert_Equal (Item.Visible_Index, 0, "a label band header is non-selectable");
               Prev_Was_Header := True;
            else
               declare
                  Name : constant String := To_String (Item.Name);
               begin
                  if Name = "Alpha.txt" then
                     Alpha_Pos := Position;
                     Header_Before_Alpha := Header_Before_Alpha or else Prev_Was_Header;
                  elsif Name = "Beta.txt" then
                     Beta_Pos := Position;
                  elsif Name = "Gamma.md" then
                     Gamma_Pos := Position;
                  end if;
               end;
               Prev_Was_Header := False;
            end if;
         end loop;

         --  Three occupied bands (Red, Blue, Unlabeled) each emit one header.
         Files_Suite.Support.Assert_Equal (Header_Count, 3, "three occupied label bands emit three headers");
         Assert (Header_Before_Alpha, "the first labeled item sits under a band header");
         --  Band order: Red (Alpha) before Blue (Gamma) before Unlabeled (Beta).
         Assert (Alpha_Pos > 0, "every real item is placed under a band (Alpha.txt)");
         Assert (Gamma_Pos > 0, "every real item is placed under a band (Gamma.md)");
         Assert (Beta_Pos > 0, "every real item is placed under a band (Beta.txt)");
         Assert (Alpha_Pos < Gamma_Pos, "the red band precedes the blue band");
         Assert (Gamma_Pos < Beta_Pos, "the blue band precedes the unlabeled band");
      end;

      --  Leaving the grouping restores the plain name order.
      Settings.Group_By := Files.Types.No_Grouping;
      Files.Model.Sync_Grouping (Model, Settings);
      declare
         Reference : Files.Model.Window_Model := Sample_Model;
      begin
         Files.Model.Set_View_Mode (Reference, Files.Types.Details);
         Files.Model.Apply_Sort
           (Reference, Files.Model.Sort_Field_Of (Model), Files.Model.Sort_Is_Ascending (Model));
         declare
            Snapshot : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Model, Settings);
            Expected : constant Files.Rendering.View_Snapshot :=
              Files.Rendering.Build_Snapshot (Reference, Settings);
         begin
            Files_Suite.Support.Assert_Equal
              (Snapshot.Items.Last_Index,
               Expected.Items.Last_Index,
               "ungrouping keeps every item");
            for Index in Snapshot.Items.First_Index .. Snapshot.Items.Last_Index loop
               Assert (not Snapshot.Items (Index).Is_Group_Header, "no band headers without grouping");
               Assert (Snapshot.Items (Index).Name = Expected.Items (Index).Name,
                       "ungrouping restores the plain sort order");
            end loop;
         end;
      end;
   end Test_Group_By_Label_Bands;
