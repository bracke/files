with Files_Suite.Support.Models;
with Files.Quick_Look;
with Files.Quick_Look.Preparation;
with Files.Model.Info_Pane;
with Files.Model.Jobs;
with Files.Model.Filtering;
with Files.Model.Quick_Look;
with Files_Suite.Listings;
with Files.Operation_Results;
separate (Files_Suite.Refresh)
   --  In a window (background transfers on, as the GUI always runs) an
   --  operation runs in its helper and the view it ran in is read again
   --  after it -- by the helper, or in the background. Either way the view
   --  keeps its place: the scroll, the info pane's scroll on its item, and
   --  Quick Look on its item, prepared afresh only when the previewed file
   --  itself changed. A new search's results are a new view, with no place
   --  in them to keep.
   procedure Test_Operation_Keeps_Place (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Notes    : constant String := Join (Root, "notes.txt");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
      Step     : Files.Operation_Results.Operation_Result;

      function Listed (Name : String) return Boolean is
        (Files_Suite.Support.Models.Visible_Index_Of (Model, Name) /= 0);

      --  The first line Quick Look shows.
      function Previewed_Line return String is
        (if Files.Model.Quick_Look.Content_Of (Model).Text_Lines.Is_Empty then ""
         else To_String (Files.Model.Quick_Look.Content_Of (Model).Text_Lines.First_Element));

      --  The place to keep: notes.txt selected and previewed, scrolled.
      procedure Take_Place is
      begin
         Select_Name (Model, "notes.txt");
         Files.Model.Set_Main_View_Scroll_Lines (Model, 15);
         Files.Model.Info_Pane.Set_Info_Pane_Scroll_Lines (Model, 3);
         Files.Model.Quick_Look.Open
           (Model, Files.Quick_Look.Preparation.Prepare (Files.Model.Selection.Selected_Item (Model)));
         Files_Suite.Support.Assert_Equal (Previewed_Line, "first", "Quick Look shows the notes");
      end Take_Place;

      --  The place Take_Place took, after What.
      procedure Assert_Place_Kept (What : String; Line : String) is
      begin
         Files_Suite.Support.Assert_Equal
           (Files.Model.Main_View_Scroll_Lines (Model), 15, What & " keeps the scroll");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selection.Selected_Name (Model), "notes.txt", What & " keeps the selection");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model), 3, What & " keeps the info pane's scroll");
         Assert (Files.Model.Quick_Look.Is_Open (Model) and then Files.Model.Quick_Look.Path (Model) = Notes,
                 What & " keeps Quick Look on its item");
         Files_Suite.Support.Assert_Equal (Previewed_Line, Line, What & ": Quick Look shows " & Line);
      end Assert_Place_Kept;
   begin
      Reset_Root;
      for Index in 1 .. 40 loop
         Write_Binary_File (Join (Root, "item" & Index'Image), "x");
      end loop;
      Write_Binary_File (Notes, "first" & ASCII.LF);
      Load := Files_Suite.Listings.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Files.Model.Jobs.Set_Background_Transfers (Model, True);
      Files.Model.Info_Pane.Toggle_Info_Pane (Model);

      --  A helper's duplicate: its own reload selects the copy, the scroll
      --  stays where it was.
      Select_Name (Model, "item 5");
      Files.Model.Set_Main_View_Scroll_Lines (Model, 15);
      Step := Complete_Operation (Model, Settings, Operation_Commands.Duplicate_Selected (Model, Settings));
      Files_Suite.Support.Assert_Equal
        (Step.Status, Files.Operation_Results.Operation_Success, "the helper duplicates the item");
      Assert (Listed ("item 5 (copy)"), "the copy is listed");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Name (Model), "item 5 (copy)", "the copy is selected");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Main_View_Scroll_Lines (Model), 15, "the helper's reload keeps the scroll");

      --  Undo, read again in the background after its helper: the place on
      --  the notes is kept, Quick Look's preview with it.
      Take_Place;
      Step := Complete_Operation (Model, Settings, Operation_Commands.Undo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert (not Listed ("item 5 (copy)"), "undo removes the copy");
      Assert_Place_Kept ("the reload after an undo", "first");

      --  The previewed file changes before a redo: the reload keeps Quick
      --  Look on it, prepared afresh.
      Write_Binary_File (Notes, "second, longer" & ASCII.LF);
      Step := Complete_Operation (Model, Settings, Operation_Commands.Redo_Last (Model, Settings));
      Await_View (Model, Settings);
      Assert (Listed ("item 5 (copy)"), "redo makes the copy again");
      Assert_Place_Kept ("the reload after a redo", "second, longer");

      --  A new search's results start at their top, with nothing selected.
      Files.Model.Filtering.Set_Filter (Model, "item");
      Step := Complete_Operation
        (Model, Settings, Operation_Commands.Run_Search (Model, Settings, Files.UI_Types.Search_Names));
      Assert (Files.Model.Filtering.Search_Results_Are_Active (Model), "the helper's results are shown");
      Files_Suite.Support.Assert_Equal (Files.Model.Main_View_Scroll_Lines (Model), 0, "new results start at the top");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Info_Pane.Info_Pane_Scroll_Lines (Model), 0, "with the info pane at its top");
      Files_Suite.Support.Assert_Equal (Files.Model.Selection.Selected_Count (Model), 0, "and nothing selected");
      Reset_Root;
   end Test_Operation_Keeps_Place;
