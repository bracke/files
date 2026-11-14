with Files.Extra_Info;
separate (Files_Suite.Refresh)
   --  A refresh the watch starts relists the folder, which used to reset the
   --  info pane: its scroll went back to the top, and the details read for
   --  the selected item (a text file's lines) went and were read again on
   --  every change in the folder. The pane now keeps its scroll on the same
   --  item, and the details while the item's facts are unchanged; a changed
   --  item, or a forced reload, reads them afresh.
   procedure Test_Refresh_Keeps_Info_Pane (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Extra_Info.Kind;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operations.Operation_Result;
      pragma Unreferenced (Step);
      --  Details no read produces: still there, they were kept, not re-read.
      Marker   : constant Files.Extra_Info.Info :=
        Files.Extra_Info.Make (Files.Extra_Info.Text_Lines, Subject => "text", Value => "marker", Count => 4_242);

      function Listed (Name : String) return Boolean is
      begin
         for Index in 1 .. Files.Model.Visible_Count (Model) loop
            if To_String (Files.Model.Visible_Item (Model, Index).Name) = Name then
               return True;
            end if;
         end loop;
         return False;
      end Listed;

      function Marked return Boolean is
        (Files.Model.Selection.Selected_Item (Model).Filetype_Extra_Loaded
         and then Files.Model.Selection.Selected_Item (Model).Filetype_Extra.Of_Kind = Files.Extra_Info.Text_Lines
         and then Files.Model.Selection.Selected_Item (Model).Filetype_Extra.Count = 4_242);

      --  A refresh as the watch starts one, once Name has arrived.
      procedure Watch_Refresh (Name : String) is
      begin
         Write_Binary_File (Join (Root, Name), "new");
         Step := Files.Refresh_Jobs.Start (Model, Settings);
         Await_View (Model, Settings);
         Assert (Listed (Name), "the refresh picks up " & Name);
      end Watch_Refresh;
   begin
      Reset_Root;
      Write_Binary_File (Join (Root, "notes.txt"), "one" & ASCII.LF & "two" & ASCII.LF);
      Write_Binary_File (Join (Root, "other.txt"), "x");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "notes.txt");
      Files.Model.Toggle_Info_Pane (Model);
      Files.Model.Set_Selected_Item_Extra (Model, Marker);
      Assert (Marked, "the details are set for the selected item");
      Files.Model.Set_Info_Pane_Scroll_Lines (Model, 3);

      Watch_Refresh ("arrived");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model), 3, "the refresh keeps the info pane's scroll");
      Assert (To_String (Files.Model.Selection.Selected_Item (Model).Name) = "notes.txt", "the selection stays");
      Assert (Marked, "the details read for the unchanged item are kept, not read again");

      --  The item itself changed: its details are read afresh.
      Write_Binary_File (Join (Root, "notes.txt"), "one" & ASCII.LF & "two" & ASCII.LF & "three" & ASCII.LF);
      Watch_Refresh ("arrived-too");
      Assert (not Marked, "a changed item's details are read again");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model), 3, "and the pane still keeps its scroll");

      --  A forced reload reads them afresh too.
      Files.Model.Set_Info_Pane_Scroll_Lines (Model, 2);
      Step := Files.Refresh_Jobs.Start (Model, Settings, Force => True);
      Await_View (Model, Settings);
      Assert (not Marked, "a forced reload reads the details again");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane_Scroll_Lines (Model), 2, "a forced reload keeps the pane's scroll as well");
   end Test_Refresh_Keeps_Info_Pane;
