separate (Files_Suite.Operations)
   procedure Test_Refresh_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
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
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "item 20");
      Files.Model.Set_Main_View_Scroll_Lines (Model, 15);
      Files.Model.Open_Quick_Look (Model, Files.Operations.Prepare_Quick_Look (Files.Model.Selected_Item (Model)));

      Write_Binary_File (Join (Root, "arrived"), "new");
      Step := Files.Refresh_Jobs.Start (Model, Settings, Force => True);
      Await_View (Model, Settings);
      Assert (Listed ("arrived"), "the refresh picks up the new file");
      Files_Suite.Support.Assert_Equal (Files.Model.Main_View_Scroll_Lines (Model), 15, "the refresh keeps the scroll");
      Assert (Files.Model.Quick_Look_Is_Open (Model)
              and then Files.Model.Quick_Look_Path (Model) = Join (Root, "item 20"),
              "the refresh keeps Quick Look on its item");

      --  A palette opened while a read is under way stays open; the result
      --  lands once it closes.
      Files.Model.Close_Quick_Look (Model);
      Write_Binary_File (Join (Root, "later"), "new");
      Step := Files.Refresh_Jobs.Start (Model, Settings, Force => True);
      Files.Model.Open_Command_Palette (Model);
      --  Wait until the read has actually finished -- its result is there to
      --  apply -- so the check below is of a result held back, not of one a
      --  slow host had simply not produced yet.
      declare
         Finished, Cancelled : Boolean := False;
      begin
         for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
            Applied := Files.Refresh_Jobs.Advance (Model, Settings);
            Files.Process_Jobs.Poll (Files.Model.Background_Refresh (Model), Finished, Cancelled);
            exit when Finished or else not Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model));
         end loop;
         Assert (Finished and then not Cancelled, "the refresh started under the palette finishes its read");
      end;
      Applied := Files.Refresh_Jobs.Advance (Model, Settings);
      Assert (Files.Model.Command_Palette_Is_Open (Model) and then not Listed ("later"),
              "an in-flight refresh neither closes the palette nor replaces the items under it");
      Assert (Files.Process_Jobs.Active (Files.Model.Background_Refresh (Model)),
              "the finished refresh is kept, waiting for the palette to close");
      Files.Model.Close_Command_Palette (Model);
      Await_View (Model, Settings);
      Assert (Listed ("later"), "the waiting refresh lands once the palette closes");
   end Test_Refresh_Keeps_Place;
