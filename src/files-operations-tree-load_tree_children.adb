with Files.Model.Tree_Panel;

separate (Files.Operations.Tree)
procedure Load_Tree_Children
  (Model      : in out Files.Model.Window_Model;
   Settings   : Files.Settings.Settings_Model;
   Node_Index : Positive) is
begin
   if Files.Model.Tree_Panel.Loads_In_Background (Model) then
      --  Read off the UI thread: a folder of 20,000 subfolders took
      --  tens of milliseconds here, seconds on a network share.
      Files.Model.Tree_Panel.Request_Children (Model, Node_Index);
   else
      Apply_Tree_Children
        (Model, Node_Index,
         Files.File_System.Load_Subdirectories
           (Files.Model.Tree_Panel.Node_Path (Model, Node_Index),
            Files.Settings.Classification_Of (Settings), Files.Settings.Listing_Options_Of (Settings)));
   end if;
end Load_Tree_Children;
