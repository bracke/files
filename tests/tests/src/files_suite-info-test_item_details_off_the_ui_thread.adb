with Files.Extra_Info_Reader;
separate (Files_Suite.Info)
   procedure Test_Item_Details_Off_The_UI_Thread (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Text     : constant String := Join (Root, "notes.txt");
   begin
      Reset_Root;
      Write_File (Text, "one" & ASCII.LF & "two" & ASCII.LF & "three" & ASCII.LF);
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Selection.Select_By_Name (Model, "notes.txt"), "the text file is listed");

      --  In a window the details are not read on the UI thread...
      Files.Model.Set_Background_Transfers (Model, True);
      Files.Operations.Ensure_Selected_Item_Extra (Model);
      Assert (Files.Model.Selected_Item_Needs_Extra (Model), "a window does not read the details while it waits");

      --  ...but asked of the reader and taken once read.
      for Attempt in Files_Suite.Support.Polling loop
         Files.Operations.Poll_Selected_Item_Extra (Model, Files.Extra_Info_Reader.Requester (401));
         exit when not Files.Model.Selected_Item_Needs_Extra (Model);
      end loop;
      Assert (not Files.Model.Selected_Item_Needs_Extra (Model), "the window's poll brings the details in");
      Files_Suite.Support.Assert_Equal
        (Files_Suite.Support.Describe (Files.Model.Selection.Selected_Item (Model).Filetype_Extra),
         Files_Suite.Support.Describe
           (Files.File_System.Extra_Info_Of (Text, Files.Types.Regular_File_Item, "text/plain")),
         "the details are those read on the spot");

      --  Without a window (a helper, a test) they are read at once.
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Set_Background_Transfers (Model, False);
      Files.Model.Toggle_Info_Pane (Model);
      Assert (Files.Model.Selection.Select_By_Name (Model, "notes.txt"), "the text file is listed again");
      Files.Operations.Ensure_Selected_Item_Extra (Model);
      Assert (not Files.Model.Selected_Item_Needs_Extra (Model), "outside a window the details are read at once");
   end Test_Item_Details_Off_The_UI_Thread;
