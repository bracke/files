with Files.Quick_Look.Preparation;
with Files_Suite.Listings;
with Files.Model.Jobs;
with Files.Operation_Results;
with Files.Model.Command_Palette;
with Files.Model.Quick_Look;
separate (Files_Suite.Refresh)
   procedure Test_Refresh_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;
      Applied  : Boolean;
      pragma Unreferenced (Step, Applied);

      function Listed (Name : String) return Boolean is
      begin
         for Index in 1 .. Files.Model.Visible_Count (Model) loop
            if To_String (Files.Model.Visible_Item (Model, Index).Name) = Name then
               return True;
            end if;
         end loop;
         return False;
      end Listed;
   begin
      Reset_Root;
      for Index in 1 .. 40 loop
         Write_Binary_File (Join (Root, "item" & Index'Image), "x");
      end loop;
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "item 20");
      Files.Model.Set_Main_View_Scroll_Lines (Model, 15);
      Files.Model.Quick_Look.Open
        (Model, Files.Quick_Look.Preparation.Prepare (Files.Model.Selection.Selected_Item (Model)));

      Write_Binary_File (Join (Root, "arrived"), "new");
      Step := Files.Refresh.Start (Model, Settings, Force => True);
      Await_View (Model, Settings);
      Assert (Listed ("arrived"), "the refresh picks up the new file");
      Files_Suite.Support.Assert_Equal (Files.Model.Main_View_Scroll_Lines (Model), 15, "the refresh keeps the scroll");
      Assert (Files.Model.Quick_Look.Is_Open (Model)
              and then Files.Model.Quick_Look.Path (Model) = Join (Root, "item 20"),
              "the refresh keeps Quick Look on its item");

      --  A palette opened while a read is under way stays open; the result
      --  lands once it closes.
      Files.Model.Quick_Look.Close (Model);
      Write_Binary_File (Join (Root, "later"), "new");
      Step := Files.Refresh.Start (Model, Settings, Force => True);
      Files.Model.Command_Palette.Open (Model);
      --  Wait until the read has actually finished -- its result is there to
      --  apply -- so the check below is of a result held back, not of one a
      --  slow host had simply not produced yet.
      declare
         Finished, Cancelled : Boolean := False;
      begin
         for Attempt in Polling loop
            Applied := Files.Refresh.Advance (Model, Settings);
            Files.Jobs.Process.Poll (Files.Model.Jobs.Background_Refresh (Model), Finished, Cancelled);
            exit when Finished or else not Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model));
         end loop;
         Assert (Finished and then not Cancelled, "the refresh started under the palette finishes its read");
      end;
      Applied := Files.Refresh.Advance (Model, Settings);
      Assert (Files.Model.Command_Palette.Is_Open (Model) and then not Listed ("later"),
              "an in-flight refresh neither closes the palette nor replaces the items under it");
      Assert (Files.Jobs.Process.Active (Files.Model.Jobs.Background_Refresh (Model)),
              "the finished refresh is kept, waiting for the palette to close");
      Files.Model.Command_Palette.Close (Model);
      Await_View (Model, Settings);
      Assert (Listed ("later"), "the waiting refresh lands once the palette closes");
   end Test_Refresh_Keeps_Place;
